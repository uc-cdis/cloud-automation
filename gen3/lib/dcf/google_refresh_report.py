import os
from os import listdir
from os.path import isfile, join
import argparse
import re

import utils

def parse_arguments():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(title="action", dest="action")

    google_refresh_cmd = subparsers.add_parser("google_refresh_report")
    google_refresh_cmd.add_argument("--manifest", required=True)
    google_refresh_cmd.add_argument("--log_dir", required=True)

    google_validate_cmd = subparsers.add_parser("google_refresh_validate")
    google_validate_cmd.add_argument("--manifest", required=True)
    google_validate_cmd.add_argument("--log_file", required=True)

    return parser.parse_args()

def google_refresh_validate(fname):
    try:
        with open(fname) as f:
            content = f.readlines()
    except IOError as e:
        print(e)
        print("Please run the dcf validation job first")
        os._exit()

    lines = [x.strip() for x in content]
    for line in lines:
        if "TOTAL GS COPY FAILURE CASES" in line:
            print(line)
            return False
    return True

def google_refresh_report(manifest, fname):
    
    #manifest = '/tmp/GDC_full_sync_legacy_manifest_20190326_post_DR16.0.tsv'
    #og_dir = "./active"

    og_files = [join(log_dir, f) for f in listdir(log_dir) if isfile(join(log_dir, f))]

    manifest_copying_files = 0
    total_data = 0
    total_copied_data = 0

    copied_objects = set()
    copying_ojects = set()

    for fname in log_files:
        with open(fname) as fread:
            for cnt, line in enumerate(fread):
                words = line.split(" ")

                copying_ojects.add(words[0])

                if words[6] == "True":
                    copied_objects.add(words[0])

    files, headers = utils.get_fileinfo_list_from_csv_manifest(manifest)
    file_dict = {}
    for fi in files:
        file_dict[fi["id"]] = fi

    for uuid in copying_ojects:
        if uuid in file_dict:
            if file_dict[uuid]["size"] > 0:
                manifest_copying_files +=1
                total_data += file_dict[uuid]["size"]*1.0/1024/1024/1024
    
    manifest_copied_files = 0
    for uuid in copied_objects:
        if uuid in file_dict:
            manifest_copied_files +=1
            total_copied_data += file_dict[uuid]["size"]*1.0/1024/1024/1024

    print(
        """
    Number of files need to be copied {}. Total {} (GB)
    Number of files were copied successfully {}. Total copied data {}
    """.format(
            manifest_copying_files,
            total_data,
            manifest_copied_files,
            total_copied_data
        )
    )

    copied_files = []
    for uuid in copied_objects:
        if uuid in file_dict:
            copied_files.append(file_dict[uuid])

    utils.write_csv(manifest[:-4] + "_gs_copied.tsv", copied_files, fieldnames=headers)


def main():
    args = parse_arguments()
    log_dir = args.log_dir
    manifest = args.manifest
    if args.action == "google_refresh_report":
        google_refresh_report(manifest, fname)
    if args.action == "google_refresh_validate":
        if google_refresh_validate(fname):
            print("All the files in the manifest have been copied to google dcf buckets")
        else:
            print("The manifest validation fails")


if __name__ == "__main__":
    main()
