import json
import argparse

import utils


def redaction(manifest, aws_log_file, gs_log_file):
    """
    """
    files, headers = utils.get_fileinfo_list_from_csv_manifest(manifest)

    file_dict = {}
    for fi in files:
        file_dict[fi["id"]] = fi

    with open(aws_log_file, "r") as fr:
        aws_log = json.loads(fr.read())
    with open(gs_log_file, "r") as fr:
        gs_log = json.loads(fr.read())
    
    aws_removed_object_num = 0
    gs_removed_object_num = 0
    total_removed_data = 0
    removed_files = []
    for element in aws_log.get("data", []):
        if element["deleted"]:
            uuid = element["url"].split("/")[-2]
            total_removed_data += file_dict[uuid]["size"] * 1.0/1024/1024/1024
            aws_removed_object_num +=1
            removed_files.append(file_dict[uuid])
    
    for element in gs_log.get("data", []):
        if element["deleted"]:
            gs_removed_object_num +=1
    
    if aws_removed_object_num != gs_removed_object_num:
        print("The numbers of removed objects from aws and google should be equal!!!")

    report = """
    Total files are removed from dcf buckets {}. Total {}(GiB)
    """.format(aws_removed_object_num, total_removed_data)
    print(report)

    print("Saving list of removed files")
    utils.write_csv(manifest.split("/")[-1][:-4] + "_removed.tsv", removed_files, fieldnames=headers)
    return report

def parse_arguments():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(title="action", dest="action")

    redaction_cmd = subparsers.add_parser("redact")
    redaction_cmd.add_argument("--manifest", required=True)
    redaction_cmd.add_argument("--aws_log", required=True)
    redaction_cmd.add_argument("--gs_log", required=True)

    return parser.parse_args()

def main():
    args = parse_arguments()
    manifest = args.manifest
    if args.action == "redact":
        redaction(manifest, args.aws_log, args.gs_log)

if __name__ == "__main__":
    main()
