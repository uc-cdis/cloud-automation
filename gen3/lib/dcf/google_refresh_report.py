import os
from os import listdir
from os.path import isfile, join
import argparse

import utils


def google_refresh_validate(fname):
    """
    Validate the google data refresh by looking into the log after validation
    script finished.
    """
    try:
        with open(fname) as f:
            content = f.readlines()
    except IOError as e:
        print(e)
        os._exit(1)

    lines = [x.strip() for x in content]
    for line in lines:
        if "TOTAL GS COPY FAILURE CASES" in line:
            print(line)
            return False
    return True

def google_refresh_report(manifest, log_dir):
    """
    Generate a google refresh report by looking into all the log files
    generated during google dataflow running. The output is a report
    containing the number of files is copied, total amount in GB was copied

    Args:
        manifest(str): GDC manifest (active or legacy)
        log(str): the directory containing logs of running google dataflow
    """

    log_files = [join(log_dir, f) for f in listdir(log_dir) if isfile(join(log_dir, f))]

    manifest_copying_files = 0
    total_data = 0
    total_copied_data = 0

    copied_objects = set()
    copying_ojects = set()

    for fname in log_files:
        with open(fname) as fread:
            for _, line in enumerate(fread):
                if "\t" in line:
                    words = line.split("\t")
                else:
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

    report = """
    Number of files need to be copied {}. Total {}(GiB)
    Number of files were copied successfully {}. Total copied data {}(GiB)
    """.format(
            manifest_copying_files,
            total_data,
            manifest_copied_files,
            total_copied_data
        )

    print(report)

    copied_files = []
    for uuid in copied_objects:
        if uuid in file_dict:
            copied_files.append(file_dict[uuid])

    utils.write_csv(manifest.split("/")[-1][:-4] + "_gs_copied.tsv", copied_files, fieldnames=headers)
    return report

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

def main():
    args = parse_arguments()
    manifest = args.manifest
    if args.action == "google_refresh_report":
        google_refresh_report(manifest, args.log_dir)
    if args.action == "google_refresh_validate":
        if google_refresh_validate(args.log_file):
            print("All the files in the manifest have been copied to google dcf buckets")
        else:
            print("The manifest validation fails")


if __name__ == "__main__":
    main()
