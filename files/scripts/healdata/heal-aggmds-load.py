#!/usr/bin/env python3
"""Pull HEAL study metadata from MDS and load a selected subset into ES.

Mimics what the AggMDS sync job (metadata-service ``src/mds/populate.py``) does
for a Gen3 commons, but for a hand-picked list of ``gen3_discovery`` fields:

1. Pages through MDS ``/metadata?data=True`` for every record whose
   ``_guid_type`` is ``discovery_metadata`` or
   ``unregistered_discovery_metadata``.
2. For each record, copies only the fields in ``GEN3_DISCOVERY_FIELDS`` out of
   its ``gen3_discovery`` section, keeping them under ``gen3_discovery`` (and
   keeping any nested structure, e.g. ``study_metadata.minimal_info.study_name``
   stays nested). The ``__manifest`` and ``external_file_metadata`` lists
   themselves are not copied; instead the doc gets ``file_manifest_size`` and
   ``external_file_metadata_size``, the number of entries in each. ``gen3_discovery``
   also gets ``commons_url`` (from ``--commons_url``) and ``commons_name``
   (always ``"HEAL"``).
3. Creates a new ES index ``<--index_name>-<UTC timestamp>`` and bulk-indexes
   one document per record, using the MDS GUID as the document ``_id``.
4. Atomically points the alias ``--index_name`` at the new index and deletes
   the index(es) it pointed at before, so searches against ``--index_name``
   never see an empty or partially loaded index. If loading fails, the new
   index is deleted and the alias is left untouched.

MDS is reached at ``--mds_url``, which defaults to the in-cluster service
(``http://metadata-service``). From outside the cluster, go through the
revproxy instead, e.g. ``--mds_url="https://healdata.org/mds"``.

Example (in-cluster):
    python heal_aggmds_load.py --index_name="healdata.org_aggmds" \
        --commons_url="healdata.org" \
        --es_url="http://esproxy-service:9200" --recreate
"""

import argparse
import copy
import json
import os
import re
import sys
from datetime import datetime, timezone

import requests

# MDS ``_guid_type`` values that hold HEAL discovery (study level) metadata.
GUID_TYPES = ["discovery_metadata", "unregistered_discovery_metadata"]

GEN3_DISCOVERY_FIELD_NAME = "gen3_discovery"

# Fields copied from each record's ``gen3_discovery`` section into the ES doc.
# Dotted names are paths into nested objects and are kept nested in the doc.
GEN3_DISCOVERY_FIELDS = [
    "authz",
    "registration_authz",
    "advSearchFilters",
    "study_metadata.minimal_info.study_description",
    "institutions",
    "investigators_name",
    "study_metadata.minimal_info.study_name",
    "project_number",
    "study_metadata.metadata_location.nih_application_id",
    "_hdp_uid",
    "dataset_1_title",
    "dataset_2_title",
    "dataset_3_title",
    "dataset_4_title",
    "administering_ic",
    "research_program",
    "doi_identifier",
    "doi_resolvable_link",
    "variable_metadata.field_standards_mappings_ids",
    "variable_metadata.field_standards_mappings_sources",
    "variable_metadata.standards_mappings_instrument_ids",
    "variable_metadata.drupal_ids",
    "variable_metadata.standards_mappings_instrument_titles",
    "variable_metadata.field_standards_mappings_id_source_combos",
    "variable_metadata.field_titles",
    "variable_metadata.field_names",
    "variable_metadata.field_descriptions",
    "research_focus_area",
    "data_availability",
    "tags",
    "is_registered",
]

# Value a field gets when it's absent (or null) in the MDS record. Fields not
# listed here are strings and default to "".
FIELD_DEFAULTS = {
    "advSearchFilters": [],
    "tags": [],
    "is_registered": False,
}
DEFAULT_STRING_VALUE = ""

# List fields in gen3_discovery whose length is stored (instead of the list
# itself, which can be huge), mapped to the doc field holding that length.
LIST_SIZE_FIELDS = {
    "__manifest": "file_manifest_size",
    "external_file_metadata": "external_file_metadata_size",
}

# Fields added under gen3_discovery in every ES doc, identifying the source commons.
COMMONS_URL_FIELD_NAME = "commons_url"
COMMONS_NAME_FIELD_NAME = "commons_name"
COMMONS_NAME = "HEAL"

# How many studies' metadata to pull per MDS page.
MDS_PAGE_SIZE = 2000
# Max documents, and default max payload size, per ES _bulk request.
ES_BULK_CHUNK_SIZE = 500
ES_BULK_MAX_BYTES = 5 * 1024 * 1024

# Default ES index body (settings + mappings). It sits next to this script
# rather than in the CWD, so the script works no matter where it is run from.
DEFAULT_MAPPING_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "config", "es_mapping.json"
)


def iter_mds_records(session, mds_url, guid_type, page_size=MDS_PAGE_SIZE):
    """Yield (guid, record) tuples for every MDS record of a given _guid_type.

    A failed page raises rather than returning early: a partial scan would
    silently produce an index that looks complete but isn't.
    """
    offset = 0
    while True:
        url = (
            f"{mds_url}/metadata"
            f"?data=True&limit={page_size}&offset={offset}&_guid_type={guid_type}"
        )
        resp = session.get(url, timeout=120)
        resp.raise_for_status()
        batch = resp.json()
        if not batch:
            return
        # data=True returns a {guid: record} mapping.
        for guid, record in batch.items():
            yield guid, record
        # Advance by what the service actually returned, not by page_size: some
        # environments cap 'limit' below what was requested, and advancing by
        # page_size there would silently skip records.
        offset += len(batch)


def get_path(obj, path):
    """Return (found, value) for a dotted path into nested dicts."""
    for key in path.split("."):
        if not isinstance(obj, dict) or key not in obj:
            return False, None
        obj = obj[key]
    return True, obj


def set_path(obj, path, value):
    """Set a dotted path in nested dicts, creating intermediate dicts."""
    *parents, leaf = path.split(".")
    for key in parents:
        obj = obj.setdefault(key, {})
    obj[leaf] = value


def record_to_doc(record, fields, commons_url):
    """Build the ES doc: the selected gen3_discovery fields, still nested under it.

    Fields absent from (or null in) the record get their default from
    FIELD_DEFAULTS, so every doc carries the same set of fields. For each entry in
    LIST_SIZE_FIELDS, the doc also gets the length of that source list, or 0 if
    it is missing, null, "" or otherwise not a list.

    gen3_discovery also carries COMMONS_URL_FIELD_NAME (``commons_url``) and
    COMMONS_NAME_FIELD_NAME (always COMMONS_NAME).
    """
    gen3 = (record or {}).get(GEN3_DISCOVERY_FIELD_NAME) or {}
    selected = {}
    for field in fields:
        found, value = get_path(gen3, field)
        if not found or value is None:
            # Copy so docs don't share one mutable default list.
            value = copy.deepcopy(FIELD_DEFAULTS.get(field, DEFAULT_STRING_VALUE))
        set_path(selected, field, value)
    for source_field, size_field in LIST_SIZE_FIELDS.items():
        value = gen3.get(source_field)
        selected[size_field] = len(value) if isinstance(value, list) else 0
    selected[COMMONS_URL_FIELD_NAME] = commons_url
    selected[COMMONS_NAME_FIELD_NAME] = COMMONS_NAME
    return {GEN3_DISCOVERY_FIELD_NAME: selected}


def get_alias_state(session, es_url, name, es_auth):
    """Return (kind, indices) for ``name``.

    kind is "alias" (indices = the indices it points to), "index" (a concrete
    index with that name, e.g. one created by an older version of this script;
    indices = [name]) or "missing" (indices = []).
    """
    resp = session.get(f"{es_url}/_alias/{name}", auth=es_auth, timeout=60)
    if resp.status_code == 200:
        return "alias", sorted(resp.json().keys())
    if resp.status_code != 404:
        resp.raise_for_status()
    resp = session.get(f"{es_url}/{name}", auth=es_auth, timeout=60)
    if resp.status_code == 200:
        return "index", [name]
    if resp.status_code != 404:
        resp.raise_for_status()
    return "missing", []


def create_es_index(session, es_url, index, mapping, es_auth):
    """Create a new concrete ES index from the mapping."""
    print(f"Creating index '{index}' ...")
    resp = session.put(f"{es_url}/{index}", json=mapping, auth=es_auth, timeout=60)
    if resp.status_code not in (200, 201):
        sys.exit(f"Error creating index '{index}': {resp.status_code} {resp.text}")


def delete_es_index(session, es_url, index, es_auth):
    resp = session.delete(f"{es_url}/{index}", auth=es_auth, timeout=60)
    if resp.status_code not in (200, 404):
        resp.raise_for_status()


def swap_alias(session, es_url, alias, new_index, kind, old_indices, es_auth):
    """Point ``alias`` at ``new_index`` and drop the old index(es), atomically.

    All actions go in one ``_aliases`` request, which ES applies as a single
    cluster-state update: searches against ``alias`` see either the old data or
    the new data, never an empty or half-loaded index. ``remove_index`` deletes
    the old index(es) as part of that same update; it is also what lets a
    concrete index named ``alias`` (left by an older version of this script) be
    replaced by an alias of the same name.
    """
    actions = [{"add": {"index": new_index, "alias": alias}}]
    if kind in ("alias", "index"):
        actions += [{"remove_index": {"index": old}} for old in old_indices]
    resp = session.post(
        f"{es_url}/_aliases", json={"actions": actions}, auth=es_auth, timeout=120
    )
    if resp.status_code != 200:
        sys.exit(
            f"Error pointing alias '{alias}' at '{new_index}': "
            f"{resp.status_code} {resp.text}\n"
            f"The new data is in '{new_index}'; '{alias}' is unchanged."
        )


def delete_orphan_indices(session, es_url, alias, keep, es_auth):
    """Delete ``<alias>-<timestamp>`` indices left behind by crashed runs."""
    resp = session.get(
        f"{es_url}/{alias}-*",
        params={"expand_wildcards": "open,closed"},
        auth=es_auth,
        timeout=60,
    )
    if resp.status_code != 200:
        return
    pattern = re.compile(re.escape(alias) + r"-\d{14}")
    for name in resp.json():
        if name != keep and pattern.fullmatch(name):
            print(f"  Deleting leftover index '{name}' from an earlier run.")
            delete_es_index(session, es_url, name, es_auth)


def bulk_load_es(session, es_url, index, docs, es_auth, max_bytes):
    """Bulk-index (guid, doc) pairs into the ES index.

    Requests are capped both by doc count and by payload size: some HEAL
    studies carry large field lists (e.g. variable_metadata), and ES (or a proxy
    in front of it, e.g. AWS OpenSearch's ~10MB limit) rejects oversized bodies
    with a 413.
    If a request still comes back 413, it is split in half and retried.

    Returns (attempted, failed) document counts.
    """
    attempted = 0
    failed = 0

    def post(entries):
        """Send pre-serialized (guid, ndjson) entries; return the failure count."""
        payload = "".join(ndjson for _, ndjson in entries).encode("utf-8")
        resp = session.post(
            f"{es_url}/_bulk",
            data=payload,
            headers={"Content-Type": "application/x-ndjson"},
            auth=es_auth,
            timeout=300,
        )
        if resp.status_code == 413:
            if len(entries) == 1:
                guid = entries[0][0]
                print(
                    f"  Warning: {guid} failed to index: the document alone "
                    f"({len(payload)} bytes) exceeds the ES request size limit."
                )
                return 1
            mid = len(entries) // 2
            return post(entries[:mid]) + post(entries[mid:])
        resp.raise_for_status()
        result = resp.json()
        if not result.get("errors"):
            return 0
        # Surface the first few item-level errors to aid debugging.
        errored = [
            item["index"]
            for item in result.get("items", [])
            if item.get("index", {}).get("error")
        ]
        print(f"  Warning: {len(errored)} document(s) failed to index.")
        for item in errored[:3]:
            print(f"    {item.get('_id')}: {item.get('error')}")
        return len(errored)

    batch = []
    batch_bytes = 0
    for guid, doc in docs:
        # Use the MDS GUID as the document _id for idempotent re-runs.
        ndjson = (
            json.dumps({"index": {"_index": index, "_id": guid}})
            + "\n"
            + json.dumps(doc)
            + "\n"
        )
        size = len(ndjson.encode("utf-8"))
        if batch and (
            len(batch) >= ES_BULK_CHUNK_SIZE or batch_bytes + size > max_bytes
        ):
            failed += post(batch)
            attempted += len(batch)
            print(f"  Sent {attempted} document(s) ...")
            batch, batch_bytes = [], 0
        batch.append((guid, ndjson))
        batch_bytes += size
    if batch:
        failed += post(batch)
        attempted += len(batch)
    return attempted, failed


def load_metadata(args):
    # A Session (rather than bare requests.get) to reuse the connection across
    # the paged MDS reads and the bulk requests.
    session = requests.Session()

    with open(args.mapping_file, encoding="utf-8") as f:
        mapping = json.load(f)

    mds_url = args.mds_url.rstrip("/")
    # Dedupe while keeping order, in case a field is listed twice.
    fields = list(dict.fromkeys(GEN3_DISCOVERY_FIELDS))

    docs = {}
    for guid_type in GUID_TYPES:
        count = 0
        print(f"Pulling '{guid_type}' records from {mds_url} ...")
        for guid, record in iter_mds_records(session, mds_url, guid_type):
            if guid in docs:
                print(
                    f"  Warning: GUID '{guid}' seen more than once; keeping the last."
                )
            docs[guid] = record_to_doc(record, fields, args.commons_url)
            count += 1
        print(f"  Received {count} record(s).")

    if not docs:
        sys.exit("Error: no metadata received from MDS; the index was not touched.")

    index = args.index_name
    es_url = args.es_url.rstrip("/")
    es_auth = (args.es_user, args.es_password) if args.es_user is not None else None

    # ``index`` is the name searches use. It is an alias onto a concrete,
    # timestamped index that each run builds from scratch, so the old data stays
    # searchable until the new index is fully loaded and the alias is swapped.
    kind, old_indices = get_alias_state(session, es_url, index, es_auth)
    if kind != "missing" and not args.recreate:
        sys.exit(
            f"Error: index '{index}' already exists. Re-run with --recreate "
            "to rebuild it."
        )

    new_index = f"{index}-{datetime.now(timezone.utc):%Y%m%d%H%M%S}"
    create_es_index(session, es_url, new_index, mapping, es_auth)
    try:
        print(f"Loading {len(docs)} document(s) into '{new_index}' ...")
        attempted, failed = bulk_load_es(
            session, es_url, new_index, docs.items(), es_auth, args.bulk_max_bytes
        )
        # Make the docs searchable before the alias goes live.
        resp = session.post(f"{es_url}/{new_index}/_refresh", auth=es_auth, timeout=60)
        resp.raise_for_status()
    except BaseException:
        print(f"Load failed; deleting '{new_index}'. '{index}' is unchanged.")
        delete_es_index(session, es_url, new_index, es_auth)
        raise

    print(f"Pointing alias '{index}' at '{new_index}' ...")
    swap_alias(session, es_url, index, new_index, kind, old_indices, es_auth)
    delete_orphan_indices(session, es_url, index, new_index, es_auth)

    print("\nLoad complete.")
    print(f"  Alias            : {index}")
    print(f"  Index            : {new_index}")
    print(f"  Documents indexed: {attempted - failed}")
    if failed:
        print(f"  Documents failed : {failed}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=(
            "Pull discovery metadata from MDS and load selected gen3_discovery "
            "fields into an Elasticsearch index."
        )
    )
    parser.add_argument(
        "--index_name",
        dest="index_name",
        action="store",
        required=True,
        help="Specify the ES index name, e.g. 'healdata.org_aggmds' (must be lowercase)",
    )
    parser.add_argument(
        "--commons_url",
        dest="commons_url",
        action="store",
        required=True,
        help=(
            "Specify the commons hostname stored in each doc's "
            "'gen3_discovery.commons_url' field, e.g. 'qa-heal.planx-pla.net'"
        ),
    )
    parser.add_argument(
        "--mds_url",
        dest="mds_url",
        action="store",
        default="http://metadata-service",
        required=False,
        help=(
            "Optional. Specify the MDS base URL. Defaults to the in-cluster "
            "service 'http://metadata-service'; from outside the cluster use "
            "e.g. 'https://healdata.org/mds'"
        ),
    )
    parser.add_argument(
        "--mapping_file",
        dest="mapping_file",
        action="store",
        default=DEFAULT_MAPPING_FILE,
        required=False,
        help=(
            "Optional. Specify the ES index body (settings + mappings) JSON file. "
            "Defaults to 'config/es_mapping.json' next to this script"
        ),
    )
    parser.add_argument(
        "--es_url",
        dest="es_url",
        action="store",
        default="http://localhost:9200",
        required=False,
        help="Optional. Specify the Elasticsearch base URL. Defaults to 'http://localhost:9200'",
    )
    parser.add_argument(
        "--recreate",
        dest="recreate",
        action="store_true",
        required=False,
        help=(
            "Optional. Rebuild the index if it already exists: load into a new "
            "index, then atomically swap the alias over and delete the old one"
        ),
    )
    parser.add_argument(
        "--bulk_max_bytes",
        dest="bulk_max_bytes",
        action="store",
        type=int,
        default=ES_BULK_MAX_BYTES,
        required=False,
        help=(
            "Optional. Max payload size in bytes of each ES _bulk request. "
            f"Defaults to {ES_BULK_MAX_BYTES} (5MB)"
        ),
    )
    parser.add_argument(
        "--es_user",
        dest="es_user",
        action="store",
        default=None,
        required=False,
        help="Optional. Elasticsearch basic-auth username",
    )
    parser.add_argument(
        "--es_password",
        dest="es_password",
        action="store",
        default=None,
        required=False,
        help="Optional. Elasticsearch basic-auth password",
    )
    args = parser.parse_args()

    if not args.mapping_file.endswith(".json"):
        print("Error: the mapping file must be a JSON file")
        exit(1)

    load_metadata(args)
