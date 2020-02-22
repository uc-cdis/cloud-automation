#!/usr/bin/env python
"""
This script will pull all the json events for all of the streams from a cloudwatch log 
and then upload to an s3 bucket. You need to put in logGroupName Example group_name = 'burwood'
profile to use in your AWS environment. You have to add the bucket you want to send your logs to as well.
Example the bucket is "inspec-data" (obj = s3.Object('inspec-data',out_file)
"""

import boto3, json, time, logging
from botocore.exceptions import ClientError
boto3.session.Session(profile_name="default")
client = boto3.client('logs', region_name="us-east-2")
s3 = boto3.resource('s3')
group_name = 'burwood'
all_streams = []
stream_batch = client.describe_log_streams(logGroupName=group_name)
all_streams += stream_batch['logStreams']
while 'nextToken' in stream_batch:
    stream_batch = client.describe_log_streams(logGroupName=group_name, nextToken=stream_batch['nextToken'])
    all_streams += stream_batch['logStreams']
    print(len(all_streams))
stream_names = [stream['logStreamName'] for stream in all_streams]
out_file = group_name + str(time.time()) + "cloud_logs.txt"
for stream in stream_names:
    logs_batch = client.get_log_events(logGroupName=group_name, logStreamName=stream)
    for event in logs_batch['events']:
        event.update({'group': group_name, 'stream': stream})
        out_file.append(json.dumps(event))
    print(stream, ":", len(logs_batch['events']))
    while 'nextToken' in logs_batch:
        logs_batch = client.get_log_events(logGroupName=group_name, logStreamName=stream,
                                           nextToken=logs_batch['nextToken'])
        for event in logs_batch['events']:
            event.update({'group': group_name, 'stream': stream})
            out_file.append(json.dumps(event))

obj = s3.Object('inspec-data',out_file)
try:
    obj.put(Body=json.dumps(out_file))
except botocore.exceptions.ClientError as e:
    if e.response['Error']['Code'] == 'NoSuchUpload':
        print(" Upload Failed")
else:
    print("Uploaded Log Files")