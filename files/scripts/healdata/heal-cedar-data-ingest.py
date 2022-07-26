import argparse
import json
import requests
import pydash
import os


parser = argparse.ArgumentParser()

parser.add_argument("--directory", help="CEDAR Directory ID for registering ")
parser.add_argument("--access_token", help="User access token")
parser.add_argument("--hostname", help="Hostname")


args = parser.parse_args()

if not args.directory:
    print("Directory ID is required!")
    exit(1)
if not args.access_token:
    print("User access token is required!")
    exit(1)
if not args.hostname:
    print("Hostname is required!")
    exit(1)

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
        exit(1)

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
            pydash.merge(mds_discovery_data_body, mds_res["gen3_discovery"], cedar_record)
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
