import argparse
import json
import requests
import os

parser = argparse.ArgumentParser()

parser.add_argument("--directory", "-d", help="Cedar Directory ID for registering ")
parser.add_argument("--access_token", "-a", help="User access token")
parser.add_argument("--hostname", "-h", help="hostname that you are running on")


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

token_header = {"Authorization": 'access_token ' + access_token}

# Get the metadata from cedar to register
cedar = requests.get(hostname+"cedar/get_directory/" + dir_id, headers=token_header)

# If we get metadata back now register with MDS
if cedar.status_code == 200:
    print("successfully got records from cedar directory")

    metadata_return = cedar.json()

    for record in metadata_return:
        cedar_record = record["appl_id"]
        print(cedar_record)

        # Get the metadata record for the nih_application_id
        mds = requests.get(hostname+"/mds/metadata/" + cedar_record,
            headers=token_header
        )
        if mds.status_code == 200:
            mds_res = mds.json()
            mds_cedar_register = {}
            if mds_res["_guid_type"] == "discovery_metadata":
                print("Metadata is already registered. Updating information  instance")
                mds_cedar_register["_guid_type"] = "discovery_metadata"
                mds_cedar_register["gen3_discovery"] = record
            elif mds_res["_guid_type"] == "unregistered_discovery_metadata":
                mds_cedar_register["_guid_type"] = "discovery_metadata"
                mds_cedar_register["gen3_discovery"] = record

            print("Metadata is now being registered.")
            mds_put = requests.put(hostname+"/mds/metadata/" + cedar_record+"?merge=true", 
                headers=token_header,
                data = mds_cedar_register
            )
            if mds_put.status_code == 200:
                print("Successfully registered: ", cedar_record)
            else:
                print("Failed to register: ", cedar_record, " Might not be MDS admin")
                print("Status from MDS:", mds_put.status_code)
        else:
            print("Failed to get information from MDS", mds.status_code)
else:
    print("Failed to get information from cedar wrapper service", cedar.status_code)
