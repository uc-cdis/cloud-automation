#!/usr/bin/env python
import csv
import os, sys
import datetime
import argparse
import boto3
from boto3 import ec2
from botocore.exceptions import ClientError

# Defaults, can be modified
AWS_ACCESS_KEY = None
AWS_SECRET_KEY = None
AWS_REGIONS = u'us-east-2|us-west-1|us-west-2|eu-west-1|ap-southeast-1|ap-northeast-1|ap-southeast-2|sa-east-1'
REPORT = 'ebs_report.csv'

def open_file(filepath):
    """
    Opens the output files, prompts whether to overwrite
    """
    goaheadandopen = True
    if os.path.exists(filepath):
        if os.path.isfile(filepath):
            valid = {'yes': True, 'y': True,
                     'no': False, 'n': False}

            while True:
                sys.stdout.write('file %s exists, overwrite it? [y/n] ' % filepath)
                choice = input().lower()
                if choice in valid.keys():
                    if not valid[choice]:
                        goaheadandopen = False
                    break
                sys.stdout.write('Please respond with \'yes\' or \'no\' (or \'y\' or \'n\').\n')
        else:  # folder
            sys.stdout.write('%s exists but nt a regular file. Aborting...\n')
            goaheadandopen = False

    if not goaheadandopen:
        return None

    try:
        f = open(filepath, 'wt')
    except Exception as e:
        f = None
        sys.stderr.write('Could not open file %s. reason: %s\n' % (filepath, e))

    return f


def ec2_connect(access_key, secret_key, region):
    #  Connects to EC2, returns a connection object
    try:
        conn = boto3.resource('ec2', region)
    except Exception as e:
        sys.stderr.write('Could not connect to region: %s. Exception: %s\n' % (region, e))
        conn = None

    return conn


def send_to_s3(file_name, bucket, ACCESS_KEY, SECRET_KEY, destination_file=None):
    s3 = boto3.resource('s3',
                        aws_access_key_id=ACCESS_KEY,
                        aws_secret_access_key=SECRET_KEY)

    if not destination_file:
        destination_file = file_name
    try:
        response = s3.Bucket(bucket).upload_file(file_name, destination_file)
    except (ClientError, FileNotFoundError) as e:
        print(traceback.format_exc())
        return False
    else:
        return True


def create_ebs_report(regions, access_key, secret_key, filepath, bucket, destination_file):
    #   Creates the actual report, first into a python data structure
    #   Then write into a csv file

    # opens file
    f = open_file(filepath)
    if not f:
        return False
    region_list = regions.split('|')

    volume_dict = {}
    # go over all regions in list
    for region in region_list:

        # connects to ec2
        conn = ec2_connect(access_key, secret_key, region)
        if not conn:
            sys.stderr.write('Could not connect to region: %s. Skipping\n' % region)
            continue

            # get all volumes and snapshots
        try:
            volumes = conn.volumes.all()
            snapshots = conn.snapshots.filter(OwnerIds=['self'])
        except ClientError as e:
            sys.stderr.write('Could not get volumes or snapshots for region: %s. Skipping (problem: %s)\n' % (
                region, e))
            continue

        volume_types_map = {u'standard': u'Standard/Magnetic', u'io1': u'Provisioned IOPS (SSD)',
                            u'gp2': u'General Purpose SSD'}
        volume_dict[region] = {}
        # goes over volumes and insert relevant data into a python dictionary
        for vol in volumes:
            try:
                name = vol.tags['Name']
            except:
                name = u''
            try:
                iops = vol.iops
            except:
                iops = 0
            if vol.state == 'in-use':
                instance_id = vol.attachments[0]['InstanceId']
                device = vol.attachments[0]['Device']
            else:
                instance_id = u'N/A'
                device = 'N/A'
            if iops == None: iops = 0

            if vol.encrypted:
                encrypted = u'yes'
            else:
                encrypted = u'no'

            volume_dict[region][vol.id] = {'name': name,
                                           'size': vol.size,
                                           'zone': vol.availability_zone,
                                           'type': volume_types_map[vol.volume_type],
                                           'iops': iops,
                                           'orig_snap': vol.snapshot_id,
                                           'encrypted': encrypted,
                                           'instance': instance_id,
                                           'device': device,
                                           'num_snapshots': 0,
                                           'first_snap_time': u'',
                                           'first_snap_id': u'N/A',
                                           'last_snap_time': u'',
                                           'last_snap_id': u'N/A'
                                           }

        # go over snapshots and match to volumes structure
        for snap in snapshots:
            start_time = snap.start_time
            if volume_dict[region].get(snap.volume_id):
                vol = volume_dict[region][snap.volume_id]
                vol['num_snapshots'] += 1
                if vol['first_snap_time'] == u'' or start_time < vol['first_snap_time']:
                    vol['first_snap_time'] = start_time
                    vol['first_snap_id'] = snap.id
                if vol['last_snap_time'] == u'' or start_time > vol['last_snap_time']:
                    vol['last_snap_time'] = start_time
                    vol['last_snap_id'] = snap.id
            else:
                sys.stdout.write(
                    'Region %s: Could not find volume %s for snapshot %s. Volume was deleted or snapshot copied from another region \n' % \
                    (region, snap.volume_id, snap.id))

        # starts the csv file
    writer = csv.writer(f)
    # header
    writer.writerow(['Region', 'volume ID', 'Volume Name', 'Volume Type', 'iops', 'Size (GiB)', \
                     'Created from Snapshot', 'Attached to', 'Device', 'Encrypted', 'Number of Snapshots', \
                     'Earliest Snapshot Time', 'Earliest Snapshot', 'Most Recent Snapshot Time',
                     'Most Recent Snapshot'])

    # writes actual data
    for region in volume_dict.keys():
        for volume_id in volume_dict[region].keys():
            volume = volume_dict[region][volume_id]
            writer.writerow([region, volume_id, volume['name'], volume['type'], volume['iops'], volume['size'],
                             volume['orig_snap'], volume['instance'], volume['device'], volume['encrypted'],
                             volume['num_snapshots'], volume['first_snap_time'], volume['first_snap_id'],
                             volume['last_snap_time'], volume['last_snap_id']])

    f.close()
    send_to_s3(filepath, bucket, access_key, secret_key, destination_file=destination_file)
    return True


if __name__ == '__main__':

    # Define command line argument parser
    parser = argparse.ArgumentParser(description='Creates a CSV report about EBS volumes and tracks snapshots on them.')
    parser.add_argument('--regions', default=AWS_REGIONS,
                        help='AWS regions to create the report on, can add multiple with | as separator. Default will assume all regions')
    parser.add_argument('--access_key', default=AWS_ACCESS_KEY, help='AWS API access key.  If missing default is used')
    parser.add_argument('--secret_key', default=AWS_SECRET_KEY, help='AWS API secret key.  If missing default is used')
    parser.add_argument('--file', default=REPORT,   help='Path for output CSV file')
    bucket = 'inspec-data'
    destination_file = ''

    args = parser.parse_args()

    # creates the report
    retval = create_ebs_report(args.regions, args.access_key, args.secret_key, args.file, bucket, destination_file)
    if retval:
        sys.exit(0)
    else:
        sys.exit(1)
