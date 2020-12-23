import datetime
import collections
import boto3
import traceback, json
import gzip
import base64
import os

cloudtrail = boto3.client('cloudtrail', 'us-east-2')
s3 = boto3.resource('s3')


def lambda_handler(event, context):
    cw_data = event['awslogs']['data']
    compressed_payload = base64.b64decode(cw_data)
    uncompressed_payload = gzip.decompress(compressed_payload)
    payload = json.loads(uncompressed_payload)
    time_discovered, account_id, username, deleted_key, aws_region = get_info(payload['logEvents'])
    endtime = datetime.datetime.now()  # Create start and end time for CloudTrail lookup
    interval = datetime.timedelta(hours=24)
    starttime = endtime - interval
    event_names, resource_names, resource_types = get_events(username, starttime, endtime)

    data = str({
        "account_id": account_id,
        "time_discovered": time_discovered,
        "username": username,
        "deleted_key": deleted_key,
        "event_names": event_names,
        "resource_names": resource_names,
        "resource_types": resource_types
    })
    s3_file = os.path.join(username, 'event_summary.txt')
    send_to_s3(data, s3_file)
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }


def get_info(log_events):
    time_discovered = None
    account_id = None
    username = None
    deleted_key = []
    aws_region = set()
    for log_event in log_events:
        message = json.loads(log_event['message'])
        if not time_discovered:
            time_discovered = log_event['timestamp']
        if not account_id:
            account_id = message['recipientAccountId']
        if not username:
            username = message['requestParameters']['userName']

        if message['eventName'] == 'DeleteAccessKey':
            key = message['requestParameters']['accessKeyId']
            deleted_key.append(key)
        region = message['awsRegion']
        aws_region.add(region)
    return time_discovered, account_id, username, deleted_key, aws_region


def send_to_s3(data, s3_file):
    # get bucket and object name
    s3_bucket = 'inspec-data'
    if s3_file:
        s3_object = s3_file
    else:
        s3_object = 'event.txt'
    s3.Object(s3_bucket, s3_object).put(Body=data)
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }


def get_events(username, starttime, endtime):
    """ Retrieves detailed list of CloudTrail events that occured between the specified time interval.
    Args:
        username (string): Username to lookup CloudTrail events for.
        starttime(datetime): Start of interval to lookup CloudTrail events between.
        endtime(datetime): End of interval to lookup CloudTrail events between.
    Returns:
        (dict)
        Dictionary containing list of CloudTrail events occuring between the start and end time with detailed information for each event.
    """
    try:
        event_name_counter = collections.Counter()
        resource_name_counter = collections.Counter()
        resource_type_counter = collections.Counter()
        response = cloudtrail.lookup_events(
            LookupAttributes=[
                {
                    'AttributeKey': 'Username',
                    'AttributeValue': username
                },
            ],
            StartTime=starttime,
            EndTime=endtime,
            MaxResults=50
        )
        get_events_summaries(response, event_name_counter, resource_name_counter, resource_type_counter)
        while response.get('NextToken'):
            NextToken = response.get('NextToken')
            response = cloudtrail.lookup_events(
                LookupAttributes=[
                    {
                        'AttributeKey': 'Username',
                        'AttributeValue': username
                    },
                ],
                StartTime=starttime,
                EndTime=endtime,
                MaxResults=50,
                NextToken=NextToken
            )
            get_events_summaries(response, event_name_counter, resource_name_counter, resource_type_counter)
            print(NextToken)
        return (event_name_counter, resource_name_counter, resource_type_counter)
    except Exception as e:
        print(traceback.format_exc())
        print(e)
        print('Unable to retrieve CloudTrail events for user "{}"'.format(username))
        raise (e)


def get_events_summaries(events, event_name_counter, resource_name_counter, resource_type_counter):
    """ Summarizes CloudTrail events list by reducing into counters of occurences for each event, resource name, and resource type in list.
    Args:
        events (dict): Dictionary containing list of CloudTrail events to be summarized.
    Returns:
        (list, list, list)
        Lists containing name:count tuples of most common occurences of events, resource names, and resource types in events list.
    """

    for event in events['Events']:
        resources = event.get("Resources")
        event_name_counter.update([event.get('EventName')])
        if resources is not None:
            resource_name_counter.update([resource.get("ResourceName") for resource in resources])
            resource_type_counter.update([resource.get("ResourceType") for resource in resources])
    return (event_name_counter.most_common(10),
            resource_name_counter.most_common(10),
            resource_type_counter.most_common(10))