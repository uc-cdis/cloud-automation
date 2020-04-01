import json
import os
import csv
import argparse
from collections import OrderedDict

parser = argparse.ArgumentParser()

parser.add_argument("--team", "-t", help="DREAM team ID")
parser.add_argument("--user", "-u", help="user audit log path")
parser.add_argument("--cert", "-c", help="cert audit log path")
parser.add_argument("--output", "-o", help="output TSV path")

args = parser.parse_args()

if not args.user:
    print("User audit log is required!")
    exit(1)

user_audit_log = args.user
cert_audit_log = args.cert
dream_team_id = args.team

output_content = []
output_filename = "audit_logs.tsv"
if args.output:
    print("Change output to:", args.output)
    output_filename = args.output

if user_audit_log is not None and os.stat(user_audit_log).st_size > 0:
    try:
        with open(user_audit_log) as json_file:
            data = json.load(json_file)
            for i in range(len(data)):
                if data[i]["new_values"]:
                    new_values = data[i]["new_values"]
                    row = OrderedDict()
                    row["User_id"] = new_values["id"]
                    row["BRAIN_username"] = new_values["username"]
                    if new_values["email"] is not None and "@" in new_values["email"]:
                        row["User_email"] = new_values["email"]
                    else:
                        row["User_email"] = ""
                    row["Synapse_id"] = ""
                    row["Synapse_email"] = ""
                    row["Synapse_sub_id"] = ""
                    row["Authorized_BEAT-PD"] = False
                    row["ToU/PP"] = "FALSE"
                    if new_values["additional_info"]:
                        if "userid" in new_values["additional_info"]:
                            row["Synapse_id"] = new_values["additional_info"]["userid"]
                        row["Synapse_email"] = new_values["additional_info"]["email"]
                        row["Synapse_sub_id"] = new_values["additional_info"]["sub"]
                        if new_values["additional_info"]["team"] and dream_team_id and (dream_team_id in new_values["additional_info"]["team"]):
                            row["Authorized_BEAT-PD"] = True

                    updated = False
                    for output_content_i, output_content_row in enumerate(output_content):
                        if output_content_row["User_id"] == row["User_id"]:
                            output_content[output_content_i] = row.copy()
                            updated = True
                    if not updated:
                        output_content.append(row.copy())
    except Exception as e: 
        print(e)
    
if cert_audit_log is not None and os.stat(cert_audit_log).st_size > 0:
    try:
        with open(cert_audit_log) as json_file:
            data = json.load(json_file)
            for cert_data in data:
                if cert_data["user_id"]:
                    for output_content_i, output_content_row in enumerate(output_content):
                        if output_content_row["User_id"] == cert_data["user_id"]:
                            output_content[output_content_i]["ToU/PP"] = "TRUE"
    except Exception as e: 
        print(e)

if not output_content:
    print("No logs parsed! Exiting...")
    exit(0)

output_content_keys = output_content[0].keys()
with open(output_filename, "w") as output_file:
    dict_writer = csv.DictWriter(output_file, fieldnames=output_content_keys, delimiter='\t')
    dict_writer.writeheader()
    dict_writer.writerows(output_content)
print("Logs saved to", output_filename)