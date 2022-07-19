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

#The name of the NLB. It should be the same as FQDN
#TODO Figure out what the hell FQDN is
env_vpn_nlb_name = "csoc-prod-vpn"

#
#TODO Figure out if this is the name of the VPC or something else
env_cloud_name = "planxprod"

#ID of the AWS account that owns the public AMIs
#TODO Figure out what this actually means
ami_account_id = "099720109477"

#
#TODO Figure out what this actually means
image_name_search_criteria = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"

#
#TODO Figure out what this means
csoc_cidr = "10.128.0.0/20"

#
#TODO Figure out what this means
env_pub_subnet_routetable_id = "rtb-1cb66860"

#
#TODO Figure out what this means
csoc_planx_dns_zone_id = "ZG153R4AYDHHK"

#The name of the aws_key_pair SSH key to attach to VMs
#TODO Figure out what service this correlates with
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
#TODO Figure out which repo this is from
branch = "master"

#
#TODO Figure out what this means
cwl_group_name = "csoc-prod-vpn.planx-pla.net_log_group"

