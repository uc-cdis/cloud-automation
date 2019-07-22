########################################################
#####Project setup info
#   Vars for creating project level related resource
#   (ie. vpc, firewall rules, vpc-peering, etc.)

#### Uncomment this if not using our makefiles
#terraform_workspace = "commons001_setup"
# ------------------------------------
#   Project Variables
# ------------------------------------

credential_file = "<credential_file>"
env = "<environment_name>"
organization = "<organization_name>"
org_id = "<organization_id>"
billing_account = "<billing_account_id>"

project_name = "new_project"
region = "us-central1"
folder = "Development"
set_parent_folder = true
create_folder = true

# ------------------------------------
#   Terraform State Variables
# -------------------------------------

state_bucket_name = "terraform-state--<bucket_id>"
state_project_name = "<seed_account_id>"

prefix_org_policies = "org_policies"
prefix_org_setup = "org_setup"
prefix_platform_setup = "platform_setup"
prefix_project_setup = "project_setup"
prefix_app_setup = "app_setup"

# ----------------------------------
#   Terraform State in CSOC Variables
# ----------------------------------

csoc_state_bucket_name = "terraform-state--<csoc_bucket_id>"

tf_state_org_setup_csoc = "csoc-org_setup_csoc"
tf_state_project_setup_csoc = "csoc-project_setup_csoc"
tf_state_app_setup_csoc = "csoc-app_setup_csoc"
prefix_org_setup_csoc = "org_setup_csoc"
prefix_app_setup_csoc = "app_setup_csoc"
prefix_project_setup_csoc = "project_setup_csoc"


# ------------------------------------
#   VPC Variables
# ------------------------------------

commons_private_subnet_ip = "<subnet_ip>"

peer_auto_create_routes = true
commons_private_network_name = "commons-private"
commons_private_subnet_name = "commons-private-kubecontrol"
commons_private_region = "us-central1"
commons_private_subnet_private_access = true
commons_private_subnet_flow_logs = true

####VPC (google_network) info
create_vpc_secondary_ranges = true

# ------------------------------------
#   VPC Alias Variables
# ------------------------------------

commons_private_subnet_secondary_name1 = "ip-cidr-range-k8-service"
commons_private_subnet_secondary_name2 = "ip-cidr-range-k8-pod"
commons_private_subnet_secondary_ip1 = "10.170.80.0/20"
commons_private_subnet_secondary_ip2 = "10.56.0.0/14"

# ------------------------------------
#   VPC Firewall Variables
# ------------------------------------

###### COMMONS INGRESS ##########
commons_ingress_direction = "INGRESS"
commons_ingress_enable_logging = true
commons_ingress_ports = ["22", "80", "443"]
commons_ingress_priority = "1000"
commons_ingress_protocol = "tcp"
commons_ingress_source_ranges = ["172.30.30.0/24"]
commons_ingress_target_tags = ["commons001-dev-ingress"]

###### COMMONS EGRESS ##########
commons_egress_destination_ranges = [""]
commons_egress_direction = "EGRESS"
commons_egress_enable_logging = true
commons_egress_ports = ["80", "443"]
commons_egress_priority = "1000"
commons_egress_protocol = "tcp"
commons_egress_target_tags = ["commons001-dev-egress"]

###### OUTBOUND FROM GKE ##########
outbound_from_gke_destination_ranges = ["172.16.0.0/28"]
outbound_from_gke_enable_logging = true
outbound_from_gke_name = "outbound-to-gke-fw"
outbound_from_gke_network_name = ""
outbound_from_gke_ports = ["1-65535"]
outbound_from_gke_priority = "1000"
outbound_from_gke_protocol = "tcp"
outbound_from_gke_target_tags = ["outbound-to-gke"]

###### INBOUND TO COMMONS ##########
inbound_to_commons_enable_logging = true
inbound_to_commons_name = "inbound-to-commons001-fw"
inbound_to_commons_network_name = ""
inbound_to_commons_ports = ["1-65535"]
inbound_to_commons_priority = "1000"
inbound_to_commons_protocol = "tcp"
inbound_to_commons_source_ranges = ["172.16.0.0/28", "172.29.30.0/24", "172.29.29.0/24"]
inbound_to_commons_target_tags = ["inbound-to-commons001"]

###### OUTBOUND FROM COMMONS ##########
outbound_from_commons_destination_ranges = ["172.29.30.0/24", "172.29.29.0/24", "172.16.0.0/28"]
outbound_from_commons_enable_logging = true
outbound_from_commons_name = "outbound-from-commons001-name"
outbound_from_commons_network_name = ""
outbound_from_commons_ports = ["1-65535"]
outbound_from_commons_priority = "1000"
outbound_from_commons_protocol = "tcp"
outbound_from_commons_target_tags = ["outbound-from-commons001"]

###### INBOUND FROM GKE ##########
inbound_from_gke_enable_logging = true
inbound_from_gke_name = "inbound-from-gke"
inbound_from_gke_network_name = ""
inbound_from_gke_ports = ["1-65535"]
inbound_from_gke_priority = "1000"
inbound_from_gke_protocol = "tcp"
inbound_from_gke_source_ranges = ["172.16.0.0/28"]
inbound_from_gke_target_tags = ["inbound-from-gke"]

# ------------------------------------
#   Google Public Access Variables
# ------------------------------------

google_apis_route = "google-apis"
fw_rule_allow_google_apis_egress = "allow-google-apis"
fw_rule_allow_hc_egress = "allow-healthcheck-egress"
fw_rule_allow_hc_ingress = "allow-healthcheck-ingress"
fw_rule_allow_master_node_egress = "allow-master-node-egress"
fw_rule_deny_all_egress = "deny-egress"

# ------------------------------------
#   GKE Variables
# ------------------------------------

cluster_name = "<cluster_name>"

cluster_secondary_range_name = "ip-cidr-range-k8-pod"
services_secondary_range_name = "ip-cidr-range-k8-service"
master_ipv4_cidr_block = "172.16.0.0/28"
min_master_version = "1.13.6-gke.5"
network_name = "commons001-dev-private"
network_policy_config = true
node_name = "commons001-dev-gke-1-node"
node_tags = ["commons001-dev-ingress", "public-google", "ingress-from-csoc2-private"]

#network                = "" #USE REMOTE_STATE
#subnetwork_name        = "" #USE REMOTE_STATE
#node_labels              = "" # USE A MAP
#password               = "" # BASIC_AUTH DISABLED
#username               = "" # BASIC_AUTH DISABLED

# ------------------------------------
#   CloudSQL Variables
# ------------------------------------

sql_name = "<sql_name>"

db_name = ["fence", "sheepdog"]
cluster_region = "us-east1"
global_address_name = "cloudsql-private-ip-address"
global_address_purpose = "VPC_PEERING"
global_address_type = "INTERNAL"
global_address_prefix = "16"
database_version = "POSTGRES_9_6"
db_instance_tier = "db-g1-small"
availability_type = "REGIONAL"
backup_enabled = "true"
backup_start_time = "02:00"
db_disk_autoresize = "true"
db_disk_size = "10"
db_disk_type = "PD_SSD"
db_maintenance_window_day = "7"
db_maintenance_window_hour = "2"
db_maintenance_window_update_track = "stable"
db_user_labels = {}
ipv4_enabled = "false"
#db_network = "default"
#sql_network = "default"
#db_authorized_networks = []
activation_policy = "ALWAYS"
db_user_name = "postgres-user"
db_user_host = "%"
db_user_password = "admin123"
#db_name = ["default"]

# ------------------------------------
#   Stackdriver Log Sink Variables
# ------------------------------------

data_access_sink_name = "data_access"
activity_sink_name = "activity"