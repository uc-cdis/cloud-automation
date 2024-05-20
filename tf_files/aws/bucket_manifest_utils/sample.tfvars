#Path to the function file
lambda_function_file = ""

#Name of the function you are creating
lambda_function_name = ""

#Description of the function
lambda_function_description = ""

#IAM role ARN to attach to the function
lambda_function_iam_role_arn = ""

#The name of the Amazon Lambda function that will handle the task. 
#For a Python-focused example, see here: https://docs.aws.amazon.com/lambda/latest/dg/python-handler.html
lambda_function_handler = "lambda_function.handler"

#Language and version to use to run the lambda function. 
#For more information, see: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
lambda_function_runtime = "python3.7"


#Timeout of the function in seconds
lambda_function_timeout = 3

#How much RAM in MB will be used
lambda_function_memory_size = 128 

#A map containing key-value pairs that define environment variables for the function
lambda_function_env = {}

#A map contaning key-value pairs used in AWS to filter and search for resources
lambda_function_tags = {}

#Whether the function will be attached to a VPC. Valid options are [true, false]
lambda_function_with_vpc = false

#List of security groups for the lambda function with a vpc
lambda_function_security_groups = []

#List of subnets for the lambda function with a vpc
lambda_function_subnets_id = []



