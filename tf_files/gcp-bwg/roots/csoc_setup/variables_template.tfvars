########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info
env = "<ENV_NAME">
project_name = "<CUSTOMER>-<APP>-<ENV_NAME>"
billing_account = "<BILLING_ACCOUNT>"
credential_file = "../credentials.json"
create_folder = true
set_parent_folder = true
folder = "<DEPT_NAME>"
region = "<REGION>"
organization = "<DOMAIN_NAME>"
org_id = "<ORG_ID>"
prefix_org_setup = "org_setup_<ENV_NAME>"
prefix_project_setup = "project_setup_<ENV_NAME>"
state_bucket_name = "<PROJECT>-tf-state"

#### Uncomment this if not using our makefiles
#terraform_workspace = "<ENV_NAME>_setup"


####VPC (google_network) info
create_vpc_secondary_ranges = true
ip_cidr_range_k8_service = "<IP_RANGE>/<CIDR>"
ip_cidr_range_k8_pod = "<IP_RANGE>/<CIDR>"

<ENV_NAME>_egress_network_name = "<ENV_NAME>-egress"
<ENV_NAME>_egress_subnet_name = "<ENV_NAME>-egress-<SUBNET_NAME>"
<ENV_NAME>_egress_region = "<REGION>"
<ENV_NAME>_egress_subnet_ip = "<IP_RANGE>/<CIDR>"
<ENV_NAME>_egress_subnet_flow_logs = true
<ENV_NAME>_egress_subnet_private_access = false

<ENV_NAME>_ingress_network_name = "<ENV_NAME>-ingress"
<ENV_NAME>_ingress_subnet_name = "<ENV_NAME>-ingress-<SUBNET_NAME>"
<ENV_NAME>_ingress_region = "<REGION>"
<ENV_NAME>_ingress_subnet_ip = "<IP_RANGE>/<CIDR>"
<ENV_NAME>_ingress_subnet_flow_logs = true
<ENV_NAME>_ingress_subnet_private_access = false

<ENV_NAME>_private_network_name = "<ENV_NAME>-private"
<ENV_NAME>_private_subnet_name = "<ENV_NAME>-private-<SUBNET_NAME>"
<ENV_NAME>_private_region = "<REGION>"
<ENV_NAME>_private_subnet_ip = "<IP_RANGE>/<CIDR>"
<ENV_NAME>_private_subnet_flow_logs = true
<ENV_NAME>_private_subnet_private_access = false

###### Firewall Rule Info
ssh_ingress_enable_logging = true
ssh_ingress_priority = "1000"
ssh_ingress_direction = "INGRESS"
ssh_ingress_protocol = "tcp"
ssh_ingress_ports = ["22"]
ssh_ingress_source_ranges = ["<IP_RANGE>/<CIDR>"]
ssh_ingress_target_tags = ["ssh-in"]

http_ingress_enable_logging = true
http_ingress_priority = "1001"
http_ingress_direction = "INGRESS"
http_ingress_protocol = "tcp"
http_ingress_ports = ["80"]
http_ingress_source_ranges = ["<IP_RANGE>/<CIDR>"]
http_ingress_target_tags = ["http-in"]

https_ingress_enable_logging = true
https_ingress_priority = "1002"
https_ingress_direction = "INGRESS"
https_ingress_protocol = "tcp"
https_ingress_ports = ["443"]
https_ingress_source_ranges = ["<IP_RANGE>/<CIDR>"]
https_ingress_target_tags = ["https-in"]

####### VPC Peering info
peer_auto_create_routes = true
