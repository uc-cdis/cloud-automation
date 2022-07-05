import argparse
import json
import requests
import os

from gen3.auth import Gen3Auth
from gen3.metadata import Gen3Metadata
from requests.auth import HTTPBasicAuth

parser = argparse.ArgumentParser()

parser.add_argument("--directory", "-d", help="Cedar Directory ID for registering ")
parser.add_argument("--access_token", "-a", help="User access token")

args = parser.parse_args()

if not args.directory:
    print("Directory ID is required!")
	exit(1)
if not args.access_token:
	print("User access token is required!")
	exit(1)

dir_id = args.directory
access_token = args.access_token

token_header = {"Authorization": 'access_token ' + access_token}

# Get the metadata from cedar to register
cedar = requests.get("http://revproxy-service/cedar/get_directory/" + dir_id, headers=token_header)

# If we get metadata back now register with MDS
if cedar.status_code == 200:
	print("successfully got records from cedar directory")

	metadata_return = cedar.json()

	for i in metadata_return:
		print(i["Metadata Location"]["Metadata Location - Details"]["nih_application_id"])

		# Get the metadata record for the nih_application_id
		mds = requests.get("http://revproxy-service/mds/metadata/" + i["Metadata Location"]["Metadata Location - Details"]["nih_application_id"],
			headers=token_header
		)
		if mds.status_code == 200:
			mds_res = mds.json()
			if mds_res["_guid_type"] == "discovery_metadata":
				print("Metadata is already registered. Skipping this instance")
			elif mds_res["_guid_type"] == "unregistered_discovery_metadata":
				mds_res["_guid_type"] = "discovery_metadata"

				print("Metadata is now being registered.")
				mds_put = requests.put("http://revproxy-service/mds/metadata/" + i["Metadata Location"]["Metadata Location - Details"]["nih_application_id"]+"?merge=true", 
					headers=token_header,
					data = mds_res
				)
				if mds_put.status_code == 200:
					Print("Successfully registered: ", i["Metadata Location"]["Metadata Location - Details"]["nih_application_id"])
				else:
					Print("Failed to register: ", i["Metadata Location"]["Metadata Location - Details"]["nih_application_id"], " Might not be MDS admin")
		else:
			print("Failed to get information from MDS", mds.status_code)
else:
	print("Failed to get information from cedar wrapper service", cedar.status_code)
