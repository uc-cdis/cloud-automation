#Automatically generated from a corresponding variables.tf on 2022-07-12 12:00:53.938872

#ID of the AWS account that owns the public AMIs
csoc_account_id = "433568766270"

#The AWS region this infrastructure will be spun up in
aws_region = "us-east-1"

#The child account that will be set as the owner of the resources created by this module
child_account_id = "707767160287"

#The region in which the child account exists
child_account_region = "us-east-1"

#The name of the environment that this will run on, for example, kidsfirst, cdistest
common_name = "cdistest"

#The name of the Elastic Search cluster
elasticsearch_domain = "commons-logs"

#A cutoff for how long of a response time is accepted, in milliseconds
threshold = "65.0"

#A webhook to send alerts to a Slack channel
slack_webhook = ""

#The ARN of a lambda function to send logs to logDNA
log_dna_function = "arn:aws:lambda:us-east-1:433568766270:function:logdna_cloudwatch"

#Timeout threshold for the Lambda function to wait before exiting
timeout = 300

#Memory allocation for the Lambda function, in MB
memory_size = 512

