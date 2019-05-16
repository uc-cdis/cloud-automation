import os
import argparse
import re

import utils


def aws_refresh_report(manifest, fname):
    """
    Generate a aws refresh report by looking into the log file
    generated during aws refresh script running. The output is a report
    containing the number of files is copied, total amount in GB was copied

    Args:
        manifest(tsv): GDC manifest (active or legacy)
        fname(str): the log file of running aws refresh script
    """
    try:
        with open(fname) as f:
            content = f.readlines()
    except IOError as e:
        print(e)
        os._exit(1)

    lines = [x.strip() for x in content]

    total_copying_files = 0
    total_data = 0
    awscli_copied_objects = set()
    awscli_copied_data = 0
    streaming_copied_objects = set()
    streaming_copied_data = 0

    
    for line in lines:
        pattern = "Total files need to be replicated: (.*)$"
        m = re.search(pattern, line)
        if m:
            total_copying_files = max(total_copying_files, int(m.group(1)))

        pattern = ".*aws s3 mv s3://.*/(.{36})/.*"
        m = re.search(pattern, line)
        if m:
            awscli_copied_objects.add(m.group(1))

        pattern = ".*aws s3 cp s3://gdcbackup/(.{36})/.*"
        m = re.search(pattern, line)
        if m:
            awscli_copied_objects.add(m.group(1))

        pattern = "successfully stream file (.{36})/.*"
        m = re.search(pattern, line)
        if m:
            streaming_copied_objects.add(m.group(1))

    files, headers = utils.get_fileinfo_list_from_csv_manifest(manifest)
    file_dict = {}
    for fi in files:
        file_dict[fi["id"]] = fi

    manifest_copied_files = 0
    for uuid in awscli_copied_objects:
        if uuid in file_dict:
            manifest_copied_files +=1
            awscli_copied_data += file_dict[uuid]["size"]*1.0/1024/1024/1024
    
    for uuid in streaming_copied_objects:
        if uuid in file_dict:
            manifest_copied_files +=1
            streaming_copied_data += file_dict[uuid]["size"]*1.0/1024/1024/1024

    report = """
    Number of files need to be copied {}. Total {} (GiB)
    Number of files were copied successfully via aws cli {}. Total {}(GiB)
    Number of files were copied successfully via gdc api {}. Total {}(GiB)
    """.format(
            total_copying_files,
            total_data,
            len(awscli_copied_objects),
            awscli_copied_data,
            len(streaming_copied_objects),
            streaming_copied_data
        )

    print(report)

    copied_files = []
    for uuid in awscli_copied_objects.union(streaming_copied_objects):
        if uuid in file_dict:
            copied_files.append(file_dict[uuid])

    print("Saving list of copied files")
    utils.write_csv(manifest.split("/")[-1][:-4] + "_aws_copied.tsv", copied_files, fieldnames=headers)
    return report

def aws_refresh_validate(fname):
    """
    Validate the aws data refresh by looking into the log after validation
    script finished.
    """
    try:
        with open(fname) as f:
            content = f.readlines()
    except IOError as e:
        print(e)
        print("Please run the dcf validation job first")
        os._exit(1)

    lines = [x.strip() for x in content]
    for line in lines:
        if "TOTAL AWS COPY FAILURE CASES" in line:
            print(line)
            return False
    return True

def parse_arguments():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(title="action", dest="action")

    aws_refresh_cmd = subparsers.add_parser("aws_refresh_report")
    aws_refresh_cmd.add_argument("--manifest", required=True)
    aws_refresh_cmd.add_argument("--log_file", required=True)

    aws_validate_cmd = subparsers.add_parser("aws_refresh_validate")
    aws_validate_cmd.add_argument("--manifest", required=True)
    aws_validate_cmd.add_argument("--log_file", required=True)

    return parser.parse_args()

def main():
    args = parse_arguments()
    fname = args.log_file
    manifest = args.manifest

    if args.action == "aws_refresh_report":
        aws_refresh_report(manifest, fname)
    elif args.action == "aws_refresh_validate":
        if aws_refresh_validate(fname):
            print("All the files in the manifest have been copied to aws dcf buckets")
        else:
            print("The manifest validation fails")


if __name__ == "__main__":
    main()
