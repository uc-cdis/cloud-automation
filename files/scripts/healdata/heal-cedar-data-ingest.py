import argparse
import json
import sys
import requests
import pydash
from uuid import UUID

# Defines how a field in metadata is going to be mapped into a key in filters
FILTER_FIELD_MAPPINGS = {
    "study_metadata.study_type.study_stage": "Study Type",
    "study_metadata.data.data_type": "Data Type",
    "study_metadata.study_type.study_subject_type": "Subject Type",
    "study_metadata.human_subject_applicability.gender_applicability": "Gender",
    "study_metadata.human_subject_applicability.age_applicability": "Age",
    "research_program": "Research Program"
}

# Defines how to handle special cases for values in filters
SPECIAL_VALUE_MAPPINGS = {
    "Interview/Focus Group - structured": "Interview/Focus Group",
    "Interview/Focus Group - semi-structured": "Interview/Focus Group",
    "Interview/Focus Group - unstructured": "Interview/Focus Group",
    "Questionnaire/Survey/Assessment - validated instrument": "Questionnaire/Survey/Assessment",
    "Questionnaire/Survey/Assessment - unvalidated instrument": "Questionnaire/Survey/Assessment",
    "Cis Male": "Male",
    "Cis Female": "Female",
    "Trans Male": "Female-to-male transsexual",
    "Trans Female": "Male-to-female transsexual",
    "Agender, Non-binary, gender non-conforming": "Other",
    "Gender Queer": "Other",
    "Intersex": "Intersexed",
    "Buisness Development": "Business Development"
}

# Defines field that we don't want to include in the filters
OMITTED_VALUES_MAPPING = {
    "study_metadata.human_subject_applicability.gender_applicability": "Not applicable"
}

def is_valid_uuid(uuid_to_test, version=4):
    """
    Check if uuid_to_test is a valid UUID.
    
     Parameters
    ----------
    uuid_to_test : str
    version : {1, 2, 3, 4}
    
     Returns
    -------
    `True` if uuid_to_test is a valid UUID, otherwise `False`.
    
    """
    
    try:
        uuid_obj = UUID(uuid_to_test, version=version)
    except ValueError:
        return False
    return str(uuid_obj) == uuid_to_test

def update_filter_metadata(metadata_to_update):
    filter_metadata = []
    for metadata_field_key, filter_field_key in FILTER_FIELD_MAPPINGS.items():
        filter_field_values = pydash.get(metadata_to_update, metadata_field_key)
        if filter_field_values:
            if isinstance(filter_field_values, str):
                filter_field_values = [filter_field_values]
            if not isinstance(filter_field_values, list):
                print(filter_field_values)
                raise TypeError("Neither a string nor a list")
            for filter_field_value in filter_field_values:
                if (metadata_field_key, filter_field_value) in OMITTED_VALUES_MAPPING.items():
                    continue
                if filter_field_value in SPECIAL_VALUE_MAPPINGS:
                    filter_field_value = SPECIAL_VALUE_MAPPINGS[filter_field_value]
                filter_metadata.append({"key": filter_field_key, "value": filter_field_value})
    filter_metadata = pydash.uniq(filter_metadata)
    metadata_to_update["advSearchFilters"] = filter_metadata
    # Retain these from existing tags
    save_tags = ["Data Repository"]
    tags = [
        tag
        for tag in metadata_to_update["tags"]
        if tag["category"] in save_tags
    ]
    # Add any new tags from advSearchFilters
    for f in metadata_to_update["advSearchFilters"]:
        tag = {"name": f["value"], "category": f["key"]}
        if tag not in tags:
            tags.append(tag)
    metadata_to_update["tags"] = tags
    return metadata_to_update


def get_client_token(client_id: str, client_secret: str):
    try:
        token_url = f"http://revproxy-service/user/oauth2/token"
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        params = {'grant_type': 'client_credentials'}
        data = 'scope=openid user data'

        token_result = requests.post(
            token_url, params=params, headers=headers, data=data,
            auth=(client_id, client_secret),
        )
        token =  token_result.json()["access_token"]
    except:
        raise Exception("Could not get token")
    return token


parser = argparse.ArgumentParser()

parser.add_argument("--directory", help="CEDAR Directory ID for registering ")
parser.add_argument("--cedar_client_id", help="The CEDAR client id")
parser.add_argument("--cedar_client_secret", help="The CEDAR client secret")
parser.add_argument("--hostname", help="Hostname")


args = parser.parse_args()

if not args.directory:
    print("Directory ID is required!")
    sys.exit(1)
if not args.cedar_client_id:
    print("CEDAR client id is required!")
    sys.exit(1)
if not args.cedar_client_secret:
    print("CEDAR client secret is required!")
    sys.exit(1)
if not args.hostname:
    print("Hostname is required!")
    sys.exit(1)

dir_id = args.directory
client_id = args.cedar_client_id
client_secret = args.cedar_client_secret
hostname = args.hostname

print("Getting CEDAR client access token")
access_token = get_client_token(client_id, client_secret)
token_header = {"Authorization": 'bearer ' + access_token}

limit = 10
offset = 0

# initialize this to be bigger than our initial call so we can go through while loop
total = 100

if not is_valid_uuid(dir_id):
    print("Directory ID is not in UUID format!")
    sys.exit(1)

while((limit + offset <= total)):
    # Get the metadata from cedar to register
    print("Querying CEDAR...")
    cedar = requests.get(f"http://revproxy-service/cedar/get-instance-by-directory/{dir_id}?limit={limit}&offset={offset}", headers=token_header)

    # If we get metadata back now register with MDS
    if cedar.status_code == 200:
        metadata_return = cedar.json()
        if "metadata" not in metadata_return:
            print("Got 200 from CEDAR wrapper but no metadata in body, something is not right!")
            sys.exit(1)

        total = metadata_return["metadata"]["totalCount"]
        returned_records = len(metadata_return["metadata"]["records"])
        print(f"Successfully got {returned_records} record(s) from CEDAR directory")
        for cedar_record in metadata_return["metadata"]["records"]:
            # get the appl id from cedar for querying in our MDS
            cedar_appl_id = pydash.get(cedar_record, "metadata_location.nih_application_id")
            if cedar_appl_id is None:
                print("This record doesn't have appl_id, skipping...")
                continue

            # Get the metadata record for the nih_application_id
            mds = requests.get(f"http://revproxy-service/mds/metadata?gen3_discovery.study_metadata.metadata_location.nih_application_id={cedar_appl_id}&data=true")
            if mds.status_code == 200:
                mds_res = mds.json()

                # the query result key is the record of the metadata. If it doesn't return anything then our query failed.
                if len(list(mds_res.keys())) == 0 or len(list(mds_res.keys())) > 1:
                    print("Query returned nothing for", cedar_appl_id, "appl id")
                    continue

                # get the key for our mds record
                mds_record_guid = list(mds_res.keys())[0]

                mds_res = mds_res[mds_record_guid]
                mds_cedar_register_data_body = {**mds_res}
                mds_discovery_data_body = {}
                mds_clinical_trials = {}
                if mds_res["_guid_type"] == "discovery_metadata":
                    print("Metadata is already registered. Updating MDS record")
                elif mds_res["_guid_type"] == "unregistered_discovery_metadata":
                    print("Metadata has not been registered. Registering it in MDS record")
                else:
                    print(f"This metadata data record has a special GUID type \"{mds_res['_guid_type']}\" and will be skipped")
                    continue

                if "clinicaltrials_gov" in cedar_record:
                    mds_clinical_trials = cedar_record["clinicaltrials_gov"]
                    del cedar_record["clinicaltrials_gov"]

                # some special handing for this field, because its parent will be deleted before we merging the CEDAR and MDS SLMD to avoid duplicated values
                cedar_record_other_study_websites = cedar_record.get("metadata_location", {}).get("other_study_websites", [])
                del cedar_record["metadata_location"]

                mds_res["gen3_discovery"]["study_metadata"].update(cedar_record)
                mds_res["gen3_discovery"]["study_metadata"]["metadata_location"]["other_study_websites"] = cedar_record_other_study_websites

                # merge data from cedar that is not study level metadata into a level higher
                deleted_keys = []
                for key, value in mds_res["gen3_discovery"]["study_metadata"].items():
                    if not isinstance(value, dict):
                        mds_res["gen3_discovery"][key] = value
                        deleted_keys.append(key)
                for key in deleted_keys:
                    del mds_res["gen3_discovery"]["study_metadata"][key]

                mds_discovery_data_body = update_filter_metadata(mds_res["gen3_discovery"])

                mds_cedar_register_data_body["gen3_discovery"] = mds_discovery_data_body
                if mds_clinical_trials:
                    mds_cedar_register_data_body["clinicaltrials_gov"] = {**mds_cedar_register_data_body.get("clinicaltrials_gov", {}), **mds_clinical_trials}

                mds_cedar_register_data_body["_guid_type"] = "discovery_metadata"

                print(f"Metadata {mds_record_guid} is now being registered.")
                mds_put = requests.put(f"http://revproxy-service/mds/metadata/{mds_record_guid}",
                    headers=token_header,
                    json = mds_cedar_register_data_body
                )
                if mds_put.status_code == 200:
                    print(f"Successfully registered: {mds_record_guid}")
                else:
                    print(f"Failed to register: {mds_record_guid}. Might not be MDS admin")
                    print(f"Status from MDS: {mds_put.status_code}")
            else:
                print(f"Failed to get information from MDS: {mds.status_code}")
    
    else:
        print(f"Failed to get information from CEDAR wrapper service: {cedar.status_code}")

    if offset + limit == total:
        break

    offset = offset + limit
    if (offset + limit) > total:
        limit = total - offset
