#Automatically generated from a corresponding variables.tf on 2022-07-13 12:13:48.803420

#
#TODO Figure out what this is
env_vpc_octet1 = "10"

#
#TODO Figure out what this is
env_vpc_octet2 = "128"

#
#TODO Figure out what this is
env_vpc_octet3 = "4"

#The ID of the VPC this NLB will reside on
env_vpc_id = "vpc-e2b51d99"

#The name of this NLB
env_nlb_name = "squid_nlb"

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this is
ami_account_id = "099720109477"

#
#TODO Figure out what this is
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

#Figure out what this is
csoc_cidr = "10.128.0.0/20"

#The ID of the public subnet
#TODO Figure out what this actually is
env_public_subnet_routetable_id = "rtb-23b6685f"

#Name of the aws_key_pair SSH key to attach to VMs
ssh_key_name = "rarya_id_rsa"

#A list of principals allowed to
#TODO Figure out what the principals are allowed to do
allowed_principals_list = ["arn:aws:iam::707767160287:root"]

#The directory in which the bootstrap script is located
bootstrap_path = "cloud-automation/flavors/squid_nlb/"

#The name of the bootstrap script
bootstrap_script = "squidvm.sh"

