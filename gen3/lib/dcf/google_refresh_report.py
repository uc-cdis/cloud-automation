import os
from os import listdir
from os.path import isfile, join
import argparse
import re

import utils

def parse_arguments():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(title="action", dest="action")

    submit_data_cmd = subparsers.add_parser("google_refresh_report")
    submit_data_cmd.add_argument("--manifest", required=True)
    submit_data_cmd.add_argument("--log_dir", required=True)

    return parser.parse_args()


def main():
    args = parse_arguments()
    if args.action != "google_refresh_report":
        return

    log_dir = args.log_dir
    manifest = args.manifest
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


if __name__ == "__main__":
    main()
