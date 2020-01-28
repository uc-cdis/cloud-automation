Gather inventory of resources from AWS environment

You need python 2 or 3
pip install aws-list-all

List all resources in an AWS account, all regions, all services(*). Writes JSON files for further processing.

mkvirtualenv -p $(which python3) aws
pip install aws-list-all
aws-list-all query --region eu-west-1 --service ec2 --directory ./data/


aws-list-all show data/ec2_*
aws-list-all show --verbose data/ec2_DescribeSecurityGroups_eu-west-1.json


Restricting the region and service is optional, a simple query without arguments lists everything. It uses a thread pool to parallelize queries and randomizes the order to avoid hitting one endpoint in close succession. One run takes around two minutes for me.



Add immediate, more verbose output to a query with --verbose. Use twice for even more verbosity:

aws-list-all query --region eu-west-1 --service ec2 --operation DescribeVpcs --directory data --verbose
Show resources for all returned queries:

aws-list-all show --verbose data/*
Show resources for all ec2 returned queries:

aws-list-all show --verbose data/ec2*
List available services to query:

aws-list-all introspect list-services
List available operations for a given service, do:

aws-list-all introspect list-operations --service ec2
List all resources in sequence to avoid throttling:

aws-list-all query --parallel 1
