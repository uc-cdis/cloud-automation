import argparse
import json
import requests
import pydash
import os


parser = argparse.ArgumentParser()

parser.add_argument("--directory", help="Cedar Directory ID for registering ")
parser.add_argument("--access_token", help="User access token")\


args = parser.parse_args()

if not args.directory:
    print("Directory ID is required!")
    exit(1)
if not args.access_token:
    print("User access token is required!")
    exit(1)

dir_id = args.directory
access_token = args.access_token

def none_to_empty_str(items):
    return {k: v if v is not None else '' for k, v in items}

token_header = {"Authorization": 'bearer ' + access_token}

# Get the metadata from cedar to register
cedar = requests.get(f"http://revproxy-service/cedar/get-instance-by-directory/{dir_id}", headers=token_header)

# If we get metadata back now register with MDS
if cedar.status_code == 200:
    print("Successfully got records from cedar directory")

    metadata_return = cedar.json(object_pairs_hook=none_to_empty_str)

    for cedar_record in metadata_return["metadata"]:
        if "appl_id" not in cedar_record:
            print("This record doesn't have appl_id, skipping...")
            continue
        cedar_record_id = str(cedar_record["appl_id"])

        # Get the metadata record for the nih_application_id
        mds = requests.get(f"https://revproxy-service/mds/metadata/{cedar_record_id}",
            headers=token_header
        )
        if mds.status_code == 200:
            mds_res = mds.json()
            mds_cedar_register = {}
            if mds_res["_guid_type"] == "discovery_metadata":
                print("Metadata is already registered. Updating MDS record")
            elif mds_res["_guid_type"] == "unregistered_discovery_metadata":
                print("Metadata is has not been registered. Registering it in MDS record")
            mds_cedar_register["_guid_type"] = "discovery_metadata"
            mds_cedar_register["gen3_discovery"] = pydash.merge(mds_cedar_register, mds_res["gen3_discovery"], cedar_record)

            print("Metadata is now being registered.")
            print(mds_cedar_register)
            mds_put = requests.put(f"https://revproxy-service/mds/metadata/{cedar_record_id}?merge=True",
                headers=token_header,
                json = mds_cedar_register
            )
            if mds_put.status_code == 200:
                print(f"Successfully registered: {cedar_record_id}")
            else:
                print(f"Failed to register: {cedar_record_id}. Might not be MDS admin")
                print(f"Status from MDS:{mds_put.status_code}")
        else:
            print(f"Failed to get information from MDS: {mds.status_code}")
else:
    print(f"Failed to get information from cedar wrapper service: {cedar.status_code}")
