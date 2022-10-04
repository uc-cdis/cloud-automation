#Automatically generated from a corresponding variables.tf on 2022-07-13 15:59:09.482879

#The subnet of the VPN
#TODO Figure out a better way to explain this
csoc_vpn_subnet = "192.168.1.0/24"

#The subnet that the VM resides on
#TODO Make sure this is accurate
csoc_vm_subnet = "10.128.2.0/24"

#The subnet for the server
#TODO Figure out what is going on here
vpn_server_subnet = "10.128.5.0/25"

#The ID for the VPC this NLB will reside on
env_vpc_id = "vpc-e2b51d99"

#The name of the network load balancer, which should be the same as the fully-qualified domain name. 
env_vpn_nlb_name = "csoc-prod-vpn"

#The hostname of the NLB
env_cloud_name = "planxprod"

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this actually means
ami_account_id = "099720109477"

#A filter to apply against the names of AMIs when searching. We search, rather than specifying a specific image,
#to ensure that all of the latest security updates are present.
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

#The CIDR of the VPC in which the admin VM is running, for peering and connection purposes
csoc_cidr = "10.128.0.0/20"

#The ID of a route table to use on the public subnet
env_pub_subnet_routetable_id = "rtb-1cb66860"

#Route53 host zone id to use for adding the vpn hostname.
csoc_planx_dns_zone_id = "ZG153R4AYDHHK"

#The name of an AWS SSH key pair to attach to EC2 instances. For more information,
#see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html
ssh_key_name = "rarya_id_rsa"

#The directory holding the bootstrap script
bootstrap_path = "cloud-automation/flavors/vpn_nlb_central/"

#The name of the bootstrap script
bootstrap_script = "vpnvm.sh"

#
#TODO Figure out what this covers
csoc_account_id = "433568766270"

#The name of the organization, for tracking and tagging purposes in AWS
organization_name = "Basic Service"

#Which branch to use
branch = "master"

#Logs group name for instances logs
cwl_group_name = "csoc-prod-vpn.planx-pla.net_log_group"

