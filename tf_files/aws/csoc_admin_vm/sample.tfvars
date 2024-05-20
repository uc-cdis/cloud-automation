#Automatically generated from a corresponding variables.tf on 2022-07-12 11:45:02.625524

#ID of AWS account the owns the public AMIs
#TODO Figure out what this means
ami_account_id = "707767160287"

#
#TODO Figure out how to phrase this, I believe it's been used before
csoc_account_id = "433568766270"

#The region in which to spin up this infrastructure.
aws_region = "us-east-1"

#The ID of the VPC on which to bring up this VM
csoc_vpc_id = "vpc-e2b51d99"

#The ID of the subnet on which to bring up this VM
csoc_subnet_id = "subnet-6127013c"

#The ID of the child account. 
child_account_id = "707767160287"

#The region for the child account
child_account_region = "us-east-1"

#NOT CURRENTLY USED
child_name = "cdistest"

#The name of the Elastic Search cluster 
elasticsearch_domain = "commons-logs"

#A list of VPC CIDR blocks that are allowed egress from the security group created by this module
vpc_cidr_list= ""

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_key_name= ""