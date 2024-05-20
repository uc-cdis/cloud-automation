#Automatically generated from a corresponding variables.tf on 2022-07-13 12:13:48.803420

#The first octet (number) of the CIDR block for this VPC
env_vpc_octet1 = "10"

#The second octet (number) of the CIDR block for this VPC
env_vpc_octet2 = "128"

##The third octet (number) of the CIDR block for this VPC
env_vpc_octet3 = "4"

#The ID of the VPC this NLB will reside on
env_vpc_id = "vpc-e2b51d99"

#The name of this NLB
env_nlb_name = "squid_nlb"

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this is
ami_account_id = "099720109477"

#A filter to apply against the names of AMIs when searching. We search, rather than specifying a specific image,
#to ensure that all of the latest security updates are present.
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

#Figure out what this is
csoc_cidr = "10.128.0.0/20"

#The ID of a route table to use on the public subnet
env_public_subnet_routetable_id = "rtb-23b6685f"

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_key_name = "rarya_id_rsa"

#The ARNs of one or more principals allowed to discover the endpoint service. For more information on the endpoint service,
#see: https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-share-your-services.html
allowed_principals_list = ["arn:aws:iam::707767160287:root"]

#The directory in which the bootstrap script is located
bootstrap_path = "cloud-automation/flavors/squid_nlb/"

#The name of the bootstrap script
bootstrap_script = "squidvm.sh"

