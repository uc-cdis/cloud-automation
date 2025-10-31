# TD;TL 

Chef Inspec is a tool that is used to audit infrastructure. It is based off of the ruby language. Chef Inspec can be used to test individual systems as well as cloud infrastructures such as AWS GCP AZURE.
Chef Inspec can execute a single test or multiple test, but in production environments you normally create a profile and then underneath that profile all the test are executed. When executing the test you point to the profile name that was created and Inspec knows how to execute the test from there. 
The test are underneath the control directory with .rb extension.

There are two ways to run, the first way is to run a cronjob from an EC2 instance using the bash script and once the test is executed the results will be uploaded to an s3 bucket.
The second way to execute the Chef Inspec test is to create a Kubernetes Cron Job to run on EKS cluster per environment. 

With the Dockerfile you need to create a docker image for your ECR repository and then add that image into the Kubernetes Cron Job Yaml and deploy the yaml to create the Kubernetes object.


## VPC Flow Logs

Opensource tool flowlogs-reader

The tools support reading Flow Logs from both CloudWatch Logs and S3. For S3 destinations, version 3 custom log formats are supported.

The library builds on boto3 and should work on Python 3.4+

You may use this library with the kinesis-logs-reader library when retrieving VPC flow logs from Amazon Kinesis.

### Installation

You can get flowlogs_reader by using pip:

```bash
pip install flowlogs_reader
```

Or if you want to install from source and/or contribute you can clone from GitHub:

```bash
git clone https://github.com/obsrvbl/flowlogs-reader.git
cd flowlogs-reader
python setup.py develop
```

### CLI Usage

flowlogs-reader provides a command line interface called flowlogs_reader that allows you to print VPC Flow Log records to your screen. It assumes your AWS credentials are available through environment variables, a boto configuration file, or through IAM metadata. Some example uses are below.

### Location types

flowlogs_reader has one required argument, location. By default that is interpreted as a CloudWatch Logs group.

To use an S3 location, specify --location-type='s3':

```bash
flowlogs_reader --location-type="s3" "bucket-name/optional-prefix"
Printing flows
```

The default action is to print flows. You may also specify the ipset, findip, and aggregate actions:

flowlogs_reader location - print all flows in the past hour
flowlogs_reader location print 10 - print the first 10 flows from the past hour
flowlogs_reader location ipset - print the unique IPs seen in the past hour
flowlogs_reader location findip 198.51.100.2 - print all flows involving 198.51.100.2
flowlogs_reader location aggregate - aggregate the flows by 5-tuple, then print them as a tab-separated stream (with a header). This requires that each of the fields in the 5-tuple are present in the data format.
You may combine the output of flowlogs_reader with other command line utilities:

flowlogs_reader location | grep REJECT - print all REJECTed Flow Log records
flowlogs_reader location | awk '$6 = 443' - print all traffic from port 443
Time windows


### Time windows

The default time window is the last hour. You may also specify a --start-time and/or an --end-time. The -s and -e switches may be used also:

```bash
flowlogs_reader --start-time='2015-08-13 00:00:00' location
flowlogs_reader --end-time='2015-08-14 00:00:00' location
flowlogs_reader --start-time='2015-08-13 01:00:00' --end-time='2015-08-14 02:00:00' location
```


### AWS options

Other command line switches:

```bash
flowlogs_reader --region='us-west-2' location - connect to the given AWS region
flowlogs_reader --profile='dev_profile' location - use the profile from your local AWS configuration file to specify credentials and regions
flowlogs_reader --role-arn='arn:aws:iam::12345678901:role/myrole' --external-id='0a1b2c3d' location - use the given role and external ID to connect to a 3rd party's account using sts assume-role
```


### For CloudWatch Logs locations:

flowlogs_reader --filter-pattern='REJECT' location - use the given filter pattern to have the server limit the output
For S3 locations:

```bash
flowlogs_reader --location-type='s3' --include-accounts='12345678901,12345678902' bucket-name/optional-prefix - return logs only for the given accounts
flowlogs_reader --location-type='s3' --include-regions='us-east-1,us-east-2' bucket-name/optional-prefix - return logs only for the given regions
```


### Module Usage
FlowRecord takes an event dictionary retrieved from a log stream. It parses the message in the event, which takes a record like this:

```
2 123456789010 eni-102010ab 198.51.100.1 192.0.2.1 443 49152 6 10 840 1439387263 1439387264 ACCEPT OK
And turns it into a Python object like this:

>>> flow_record.srcaddr
'198.51.100.1'
>>> flow_record.dstaddr
'192.0.2.1'
>>> flow_record.srcport
443
>>> flow_record.to_dict()
{'account_id': '123456789010',
 'action': 'ACCEPT',
 'bytes': 840,
 'dstaddr': '192.0.2.1',
 'dstport': 49152,
 'end': datetime.datetime(2015, 8, 12, 13, 47, 44),
 'interface_id': 'eni-102010ab',
 'log_status': 'OK',
 'packets': 10,
 'protocol': 6,
 'srcaddr': '198.51.100.1',
 'srcport': 443,
 'start': datetime.datetime(2015, 8, 12, 13, 47, 43),
 'version': 2}
FlowLogsReader reads from CloudWatch Logs. It takes the name of a log group and can then yield all the Flow Log records from that group.

>>> from flowlogs_reader import FlowLogsReader
... flow_log_reader = FlowLogsReader('flowlog_group')
... records = list(flow_log_reader)
... print(len(records))
176
S3FlowLogsReader reads from S3. It takes a bucket name or a bucket/prefix identifier.
```

By default these classes will yield records from the last hour.

You can control what's retrieved with these parameters:

start_time and end_time are Python datetime.datetime objects
region_name is a string like 'us-east-1'. This will be used to create a boto3 Session object.
profile_name is a string like 'my-profile'
boto_client_kwargs is a dictionary of parameters to pass when creating the boto3 client.
boto_client is a boto3 client object. This takes overrides region_name, profile_name, and boto_client_kwargs



### When using FlowLogsReader with CloudWatch Logs:

The filter_pattern keyword is a string like REJECT or 443 used to filter the logs. See the examples below.
When using S3FlowLogsReader with S3:

The include_accounts keyword is an iterable of account identifiers (as strings) used to filter the logs.
The include_regions keyword is an iterable of region names used to filter the logs.



### Examples
Start by importing FlowLogsReader:

from flowlogs_reader import FlowLogsReader
Find all of the IP addresses communicating inside the VPC:

ip_set = set()
for record in FlowLogsReader('flowlog_group'):
    ip_set.add(record.srcaddr)
    ip_set.add(record.dstaddr)



See all of the traffic for one IP address:


target_ip = '192.0.2.1'
records = []
for record in FlowLogsReader('flowlog_group'):
    if (record.srcaddr == target_ip) or (record.dstaddr == target_ip):
        records.append(record)
Loop through a few preconfigured profiles and collect all of the IP addresses:

ip_set = set()
profile_names = ['profile1', 'profile2']
for profile_name in profile_names:
    for record in FlowLogsReader('flowlog_group', profile_name=profile_name):
        ip_set.add(record.srcaddr)
        ip_set.add(record.dstaddr)
Apply a filter for UDP traffic that was logged normally (CloudWatch Logs only):

FILTER_PATTERN = (
    '[version="2", account_id, interface_id, srcaddr, dstaddr, '
    'srcport, dstport, protocol="17", packets, bytes, '
    'start, end, action, log_status="OK"]'
)

flow_log_reader = FlowLogsReader('flowlog_group', filter_pattern=FILTER_PATTERN)
records = list(flow_log_reader)
print(len(records))




#### Retrieve logs from a list of regions:

from flowlogs_reader import S3FlowLogsReader

reader = S3FlowLogsReader('example-bucket/optional-prefix', include_regions=['us-east-1', 'us-east-2'])
records = list(reader)
print(len(records))
You may aggregate records with the aggregate_records function. Pass in a FlowLogsReader or S3FlowLogsReader object and optionally a key_fields tuple. Python dict objects will be yielded representing the aggregated flow records. By default the typical ('srcaddr', 'dstaddr', 'srcport', 'dstport', 'protocol') will be used. The start, end, packets, and bytes items will be aggregated.

flow_log_reader = FlowLogsReader('flowlog_group')
key_fields = ('srcaddr', 'dstaddr')
records = list(aggregated_records(flow_log_reader, key_fields=key_fields))



#### List Server Certificates


* Using Python Boto3 Library in AWS

Example

```python
import bot3

# Create an IAM client

iam = boto3.client('iam')

# List server certificates through the pagination interface
paginator = iam.get_paginator('list_server_certificates')
for response in paginator.paginate():
    print(response['ServerCertificateMetadataList'])
```


* Use the AWS command line 

Example 

```bash
aws iam list-server-certificates
```


* List ebs volumes and status

Using Python Boto3 Library


```python
import boto3
ec2 = boto3.resource('ec2', region_name='us-west-2')
volumes = ec2.volumes.all() # If you want to list out all volumes
volumes = ec2.volumes.filter(Filters=[{'Name': 'status', 'Values': ['in-use']}]) # if you want to list out only attached volumes
[volume for volume in volumes]
```


### List AWS Inventory

Gather inventory of resources from AWS environment

You need python 2 or 3

```bash
pip install aws-list-all
```

List all resources in an AWS account, all regions, all services(\*). Writes JSON files for further processing.

```bash
mkvirtualenv -p $(which python3) aws
pip install aws-list-all
aws-list-all query --region eu-west-1 --service ec2 --directory ./data/


aws-list-all show data/ec2_*
aws-list-all show --verbose data/ec2_DescribeSecurityGroups_eu-west-1.json
```

Restricting the region and service is optional, a simple query without arguments lists everything. It uses a thread pool to parallelize queries and randomizes the order to avoid hitting one endpoint in close succession. One run takes around two minutes for me.



Add immediate, more verbose output to a query with --verbose. Use twice for even more verbosity:

```bash
aws-list-all query --region eu-west-1 --service ec2 --operation DescribeVpcs --directory data --verbose
```


Show resources for all returned queries:
```bash
aws-list-all show --verbose data/*
```

Show resources for all ec2 returned queries:
```bash
aws-list-all show --verbose data/ec2*
```


List available services to query:
```bash
aws-list-all introspect list-services
```


List available operations for a given service, do:

```bash
aws-list-all introspect list-operations --service ec2
```

List all resources in sequence to avoid throttling:

### Get Cloudwatch Logs

There is a python script that will pull json events for all of the streams from cloudwatch log and it will send the output to an S3 bucket.You
need to provide a group_name, bucket name


Get EBS volume and check to see if they are encrypted

There is a python script the runs a report and uploads the report as a csv file into an s3 bucket of choice. The report list the volume, volume type, iops, size, created from a snapshot (if) the instances it is attached and if it is encrypted or not. The command takes argument of region if the instance has sufficient IAM role it should run. I know each environment is different and how you pass credentials will vary. You will need to go down the line in the code near the bottom where it says bucket and change to your bucket. You can also set the default regions in the code and dropp the argument --regions when executing the script

## Example

```bash:
ebs-report.py --regions us-east-2 --file my-ebs-report.csv
```




## CloudTrail Logs

Bash script to pull CloudTrail logs us just have to provide the values in the script Bucket Name Account Number and Region


### CloudTrail Lambda Function

This cloudtrail_lambda.py function will get cloudtrail events and send the events to and s3 bucket as text file. This lambda function is invoked from iam activity. You need to have a cloudtrail trail setup and cloudwatch logging setup to receive the logs. The time for the lambda function should be set to 5 minutes if you want it check all regions. The lambda function was executed using Python 3.8 and this lambda function will need permissions to access 33 bucket, cloudtrail and cloudwatch and will vary depending on the security protocol for your environment.
When you are setting up the log group you select cloudwatch log group select action select stream to lambda then select other then you will put in stream pattern. Here is the stream pattern that you can set for all actions against IAM activity 

```
{ ( ($.eventSource = "iam.amazonaws.com") && (($.eventName = "Add*") || ($.eventName = "Attach*") || ($.eventName = "Change*") || ($.eventName = "Create*") || ($.eventName = "Deactivate*") || ($.eventName = "Delete*") || ($.eventName = "Detach*") || ($.eventName = "Enable*") || ($.eventName = "Put*") || ($.eventName = "Remove*") || ($.eventName = "Set*") || ($.eventName = "Update*") || ($.eventName = "Upload*")) ) }
```

When you stream cloudwatch logs to lambda that will create trigger on lambda.


