import argparse
import sys
import requests
import pydash

# Defines how a field in metadata is going to be mapped into a key in filters
FILTER_FIELD_MAPPINGS = {
    "Study Type.study_stage": "Study Type",
    "Data.data_type": "Data Type",
    "Study Type.study_subject_type": "Subject Type",
    "Human Subject Applicability.gender_applicability": "Gender",
    "Human Subject Applicability.age_applicability": "Age"
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
    "Intersex": "Intersexed"
}

# Defines field that we don't want to include in the filters
OMITTED_VALUES_MAPPING = {
    "Human Subject Applicability.gender_applicability": "Not applicable"
}

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
    return metadata_to_update

parser = argparse.ArgumentParser()

parser.add_argument("--directory", help="CEDAR Directory ID for registering ")
parser.add_argument("--access_token", help="User access token")
parser.add_argument("--hostname", help="Hostname")


args = parser.parse_args()

if not args.directory:
    print("Directory ID is required!")
    sys.exit(1)
if not args.access_token:
    print("User access token is required!")
    sys.exit(1)
if not args.hostname:
    print("Hostname is required!")
    sys.exit(1)

dir_id = args.directory
access_token = args.access_token
hostname = args.hostname

token_header = {"Authorization": 'bearer ' + access_token}

# Get the metadata from cedar to register
print("Querying CEDAR...")
cedar = requests.get(f"https://{hostname}/cedar/get-instance-by-directory/{dir_id}", headers=token_header)

# If we get metadata back now register with MDS
if cedar.status_code == 200:
    metadata_return = cedar.json()
    if "metadata" not in metadata_return:
        print("Got 200 from CEDAR wrapper but no metadata in body, something is not right!")
        sys.exit(1)

    print(f"Successfully got {len(metadata_return['metadata'])} record(s) from CEDAR directory")
    for cedar_record in metadata_return["metadata"]:
        if "appl_id" not in cedar_record:
            print("This record doesn't have appl_id, skipping...")
            continue
        cedar_record_id = str(cedar_record["appl_id"])

        # Get the metadata record for the nih_application_id
        mds = requests.get(f"https://{hostname}/mds/metadata/{cedar_record_id}",
            headers=token_header
        )
        if mds.status_code == 200:
            mds_res = mds.json()
            mds_cedar_register_data_body = {}
            mds_discovery_data_body = {}
            if mds_res["_guid_type"] == "discovery_metadata":
                print("Metadata is already registered. Updating MDS record")
            elif mds_res["_guid_type"] == "unregistered_discovery_metadata":
                print("Metadata is has not been registered. Registering it in MDS record")
                continue
            pydash.merge(mds_discovery_data_body, mds_res["gen3_discovery"], cedar_record)
            mds_discovery_data_body = update_filter_metadata(mds_discovery_data_body)
            mds_cedar_register_data_body["gen3_discovery"] = mds_discovery_data_body
            mds_cedar_register_data_body["_guid_type"] = "discovery_metadata"

            print("Metadata is now being registered.")
            mds_put = requests.put(f"https://{hostname}/mds/metadata/{cedar_record_id}",
                headers=token_header,
                json = mds_cedar_register_data_body
            )
            if mds_put.status_code == 200:
                print(f"Successfully registered: {cedar_record_id}")
            else:
                print(f"Failed to register: {cedar_record_id}. Might not be MDS admin")
                print(f"Status from MDS: {mds_put.status_code}")
        else:
            print(f"Failed to get information from MDS: {mds.status_code}")
else:
    print(f"Failed to get information from CEDAR wrapper service: {cedar.status_code}")
