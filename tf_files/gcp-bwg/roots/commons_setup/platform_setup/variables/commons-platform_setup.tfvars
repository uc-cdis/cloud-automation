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
prefix_org_policies = "org_policies_commons001"
prefix_org_setup = "org_setup_commons0001"
prefix_project_setup = "project_setup_commons001"
prefix_platform_setup = "platform_setup_commons001"

#### Uncomment this if not using our makefiles
#terraform_workspace = "commons001_setup"

### Cloud SQL SETUP Info
sql_name = "test-sql-01"
db_name = ["fence","sheepdog"]

/*

####VPC (google_network) info
create_vpc_secondary_ranges = true
commons001-dev_private_region = "us-central1"
commons001-dev_private_subnet_flow_logs = true
commons001-dev_private_subnet_private_access = false

commons001-dev_private_network_name = "commons001-private"
commons001-dev_private_subnet_name = "commons001-private-kubecontrol"
commons001-dev_private_subnet_ip = "172.30.30.0/24"

commons001-dev_private_subnet_secondary_name1 = "ip-cidr-range-k8-service"
commons001-dev_private_subnet_secondary_ip1 = "10.170.80.0/20" 
commons001-dev_private_subnet_secondary_name2 = "ip-cidr-range-k8-pod"
commons001-dev_private_subnet_secondary_ip2 = "10.56.0.0/14"



### GKE SETUP Info
cluster_name           = "commons001-gke-1"
node_name              = "commons001-gke-1-node"
#network                = "" #USE REMOTE_STATE
#username               = "" # BASIC_AUTH DISABLED
#password               = "" # BASIC_AUTH DISABLED
#environment            = "" # USE env
network_policy_config = true
#master_ipv4_cidr_block = "${var.master_ipv4_cidr_block}"
#subnetwork_name        = "" #USE REMOTE_STATE
node_tags            = ["commons001-ingress", "public-google"]
#node_labels              = "" # USE A MAP
cluster_secondary_range_name = "ip-cidr-range-k8-pod"
services_secondary_range_name = "ip-cidr-range-k8-service"

######### Google Public Access Info ###########################

network_name = "commons001-private"
fw_rule_deny_all_egress = "deny-egress"
fw_rule_allow_hc_ingress = "allow-healthcheck-ingress"
fw_rule_allow_hc_egress = "allow-healthcheck-egress"
fw_rule_allow_google_apis_egress = "allow-google-apis"
fw_rule_allow_master_node_egress = "allow-master-node-egress"
*/