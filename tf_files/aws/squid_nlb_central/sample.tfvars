#Automatically generated from a corresponding variables.tf on 2022-07-13 11:07:41.300390

#ID of the account that will own the NLB
aws_account_id = "433568766270"

#
#TODO Figure out what the hell this is
env_vpc_octet3 = "4"

#The ID of the VPC this NLB will be spun up in
env_vpc_id = "vpc-e2b51d99"

#The name to be assigned to this NLB
#TODO Ensure that this is accurate
env_nlb_name = "squid_nlb"

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this actually means
ami_account_id = "099720109477"

#
#TODO Figure out what this actually means
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

#
#TODO Figure out what this is
env_pub_subnet_routetable_id = "rtb-1cb66860"

#The name of the aws_key_pair SSH key to attach to VMs
#TODO Get better documentation on this
ssh_key_name = "rarya_id_rsa"

#The path where the bootstrap script is located
bootstrap_path = "cloud-automation/flavors/squid_nlb_central/"

#The name of the bootstrap script
bootstrap_script = "squidvm.sh"

#
#TODO Figure out what this is
csoc_internal_dns_zone_id = "ZA1HVV5W0QBG1"

#
#TODO Figure out what this is
csoc_cidr = "10.128.0.0/20"

#A list of principals allowed to: 
#TODO figure out what the principals are allowed to
allowed_principals_list = ["arn:aws:iam::707767160287:root"]