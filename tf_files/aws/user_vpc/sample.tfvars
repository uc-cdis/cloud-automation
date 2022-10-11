#Automatically generated from a corresponding variables.tf on 2022-07-13 12:46:49.785683

#The name of this VPC
vpc_name = "Commons1"

##The second octet (number) of the CIDR block for this VPC
vpc_octet2 = 24

##The third octet (number) of the CIDR block for this VPC
vpc_octet3 = 17

#The AWS region this resource should be brought up in
aws_region = "us-east-1"

#The public key that will be used to create an AWS key pair for automation
ssh_public_key= ""

#ID of the AWS account that owns the public AMIs
#TODO Figure out what exactly this means
ami_account_id = "707767160287"

#The CIDR block for the VPC where the admin VM is running
csoc_cidr = "10.128.0.0/20"

