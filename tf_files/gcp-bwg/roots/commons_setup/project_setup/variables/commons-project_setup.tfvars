########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info

env = "commons001"
project_name = "<project_name_here>"
billing_account = "<billing_account_here>"
credential_file = "<credentials_here>.json"
create_folder = true
set_parent_folder = true
folder = "<folder_name_here>"
region = "us-central1"
organization = "<organization_name_here>"
org_id = "<org_id_here>"
###### Terraform State
state_bucket_name = "<tfstate_bucket_here>"
csoc_state_bucket_name = "<csoc_tfstate_bucket_here>"
tf_state_project_setup_csoc = "<csoc_tfstate_file_here>"
prefix_org_policies = "org_policies_commons001"
prefix_org_setup = "org_setup_commons001"
prefix_project_setup = "project_setup_commons001"
prefix_project_setup_csoc = "project_setup_csoc"
#### Uncomment this if not using our makefiles
#terraform_workspace = "commons001_setup"

####VPC (google_network) info
create_vpc_secondary_ranges = true
commons001-dev_private_region = "us-central1"
commons001-dev_private_subnet_flow_logs = true
commons001-dev_private_subnet_private_access = true

commons001-dev_private_network_name = "commons001-private"
commons001-dev_private_subnet_name = "commons001-private-kubecontrol"
commons001-dev_private_subnet_ip = "172.30.30.0/24"

commons001-dev_private_subnet_secondary_name1 = "ip-cidr-range-k8-service"
commons001-dev_private_subnet_secondary_ip1 = "10.170.80.0/20" 
commons001-dev_private_subnet_secondary_name2 = "ip-cidr-range-k8-pod"
commons001-dev_private_subnet_secondary_ip2 = "10.56.0.0/14"


###### Firewall Rule Info
commons001-dev_ingress_enable_logging = true
commons001-dev_ingress_priority = "1000"
commons001-dev_ingress_direction = "INGRESS"
commons001-dev_ingress_protocol = "tcp"
commons001-dev_ingress_ports = ["22", "80", "443"]
commons001-dev_ingress_source_ranges = ["172.30.30.0/24"]
commons001-dev_ingress_target_tags = ["commons001-ingress"]

commons001-dev_egress_enable_logging = true
commons001-dev_egress_priority = "1000"
commons001-dev_egress_direction = "EGRESS"
commons001-dev_egress_protocol = "tcp"
commons001-dev_egress_ports = ["80", "443"]
commons001-dev_egress_destination_ranges = [""]
commons001-dev_egress_target_tags = ["commons001-egress"]
####### VPC Peering info
peer_auto_create_routes = true
google_apis_route = "google-apis"

