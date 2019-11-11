# ------------------------------------------------------------------
#
#   Variables for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
# ------------------------------------------------------------------
# ------------------------------------------------------------------
#
#   TERRAFORM STATE VARIABLES
#
# ------------------------------------------------------------------
# ------------------------------------
#   Terraform State Variables
# -------------------------------------

env = "<environment_name>"

# BUCKET NAME THAT HOSTS TERRAFORM STATE
state_bucket_name = "terraform-state--<bucket_id>"
state_project_name = "<seed_account_id>"

# FOLDERS INSIDE BUCKETS
prefix_org_policies = "org_policies"
prefix_org_setup = "org_setup"
prefix_platform_setup = "platform_setup"
prefix_project_setup = "project_setup"
prefix_app_setup = "app_setup"

# ----------------------------------
#   Terraform State in CSOC Variables
# ----------------------------------

# BUCKET NAME THAT HOSTS TERRAFORM STATE IN CSOC
state_bucket_name_csoc = "terraform-state--<csoc_bucket_id>"

# FOLDERS INSIDE BUCKETS IN CSOC
prefix_org_setup_csoc = "org_setup_csoc"
prefix_app_setup_csoc = "app_setup_csoc"
prefix_project_setup_csoc = "project_setup_csoc"

# STATE FILE NAMES INSIDE BUCKET IN CSOC
tf_state_org_setup_csoc = "csoc-org_setup_csoc"
tf_state_project_setup_csoc = "csoc-project_setup_csoc"
tf_state_app_setup_csoc = "csoc-app_setup_csoc"

# ------------------------------------------------------------------
#
#   ORGANIZATION POLICIES SETUP
#
# ------------------------------------------------------------------
# -------------------------------------
#   Org Policy Variables
# -------------------------------------

# UNCOMMENT IF DESIRED
constraint = ["constraints/compute.disableNestedVirtualization","constraints/compute.disableSerialPortAccess","constraints/compute.skipDefaultNetworkCreation"]
org_iam_externalipaccess = []

#### Role Bindings to group and user accounts
#org_administrator_org_binding=["group:org_admins@domain.com"]
#org_viewer_org_binding = []
#folder_viewer_org_binding = [""]
#all_projects_org_owner = [""]
#projects_viewer_org_binding = [""]
#billing_account_admin = [""]
#billing_account_user = [""]
#billing_account_viewer = [""]
#log_viewer_org_binding = [""]
#log_viewer_folder_binding = [""]
#org_policy_viewer_org_binding = [""]

#network_admin_org_binding = [""]
#stackdriver_monitoring_viewer_folder_binding = [""]
#stackdriver_monitoring_viewer_org_binding = [""]
#kubernetes_engine_viewer_folder_binding = [""]
#compute_instance_viewer_folder_binding = [""]
#service_account_creator_folder_level = [""]
# ------------------------------------------------------------------
#
#   ORGANIZATION SETUP
#
# ------------------------------------------------------------------

organization = "<organization_name>"
org_id = "<organization_id>"
billing_account = "<billing_account_id>"
credential_file = "<credential_file>"

# -------------------------------------
#   Folder Variables
# -------------------------------------

create_folder = true
set_parent_folder = true
folder = "Development"

# ------------------------------------
#   Project Variables
# ------------------------------------

project_name = "<desire_project_name>"
region = "<region>"

# ------------------------------------------------------------------
#
#   PROJECT SETUP
#
# ------------------------------------------------------------------
# ------------------------------------
#   VPC Variables
# ------------------------------------

# VPC NETWORK
commons_private_network_name = "commons-private"

# VPC SUBNETWORK
commons_private_subnet_name = "commons-private-kubecontrol"
commons_private_subnet_ip = "<subnet_ip>"
commons_private_region = "<region>"
commons_private_subnet_private_access = true
commons_private_subnet_flow_logs = true

# VPC SUBNETWORK ALIAS
commons_private_subnet_secondary_name1 = "ip-cidr-range-k8-service"
commons_private_subnet_secondary_name2 = "ip-cidr-range-k8-pod"
commons_private_subnet_secondary_ip1 = "<cidr_block>"
commons_private_subnet_secondary_ip2 = "<cidr_block>"

# VPC PEERING INFORMATION
peer_auto_create_routes = true

# VPC (google_network) info
create_vpc_secondary_ranges = true

# ------------------------------------
#   VPC Firewall Variables
# ------------------------------------

###### INBOUND PROXY PORT
inbound_proxy_port_priority = "800"
inbound_proxy_port_name = "allow-inbound-proxy-port"
inbound_proxy_port_ports = ["3128"]

###### OUTBOUND PROXY TRAFFIC
egress_allow_proxy_mig_priority = "100"
egress_allow_proxy_mig_name = "allow-proxy-traffic"
egress_allow_proxy_mig_protocol = "all"

###### OUTBOUND CONNECT TO PROXY
egress_allow_proxy_priority = "900"
egress_allow_proxy_name = "allow-connect-to-proxy"
egress_allow_proxy_protocol = "TCP"
egress_allow_proxy_ports = ["3128"]

###### OUTBOUND DENY ALL
egress_deny_all_protocol = "all"
egress_deny_all_name = "deny-all"
egress_deny_all_priority = "65534"

# ------------------------------------
#   Google Public Access Variables
# ------------------------------------

google_apis_route = "google-apis"
fw_rule_allow_google_apis_egress = "allow-google-apis"
fw_rule_allow_hc_egress = "allow-healthcheck-egress"
fw_rule_allow_hc_ingress = "allow-healthcheck-ingress"
fw_rule_allow_master_node_egress = "allow-master-node-egress"
fw_rule_deny_all_egress = "deny-egress"

# ------------------------------------------------------------------
#
#   PLATFORM SETUP
#
# ------------------------------------------------------------------
# ------------------------------------
#   GKE Variables
# ------------------------------------

cluster_name = "<cluster_name>"
cluster_region = "<region>"
master_ipv4_cidr_block = "<master_cidr>/28"
min_master_version = "<gke_min_master_version>"
network_policy_config = true
node_name = "<node_names>"
node_labels = {
  "data-commons" = "data-commons"
  "department" = "ctds"
  "environment" = "production"
  "sponsor" = "sponsor"
}

# -----------------------------------
#   Firewall Rules to add to CSOC PRIVATE
# ------------------------------------

csoc_private_egrees_gke_endpoint = "egress-gke-endpoint"
csoc_private_ingress_gke_endpoint = "ingress-gke-endpoint"

# ------------------------------------
#   CloudSQL Variables
# ------------------------------------

sql_name = "<sql_name>"
db_name = ["<db_name>"]
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
db_user_labels = {
  "data-commons" = "data-commons"
  "department" = "ctds"
  "environment" = "production"
  "sponsor" = "sponsor"
}
ipv4_enabled = "false"
activation_policy = "ALWAYS"
db_user_name = "postgres-user"
db_user_host = "%"
db_user_password = "admin123"

# ------------------------------------
#   Stackdriver Log Sink Variables
# ------------------------------------

data_access_sink_name = "data_access"
activity_sink_name = "activity"

# -------------------------------------
#   SQUID MANAGED INSTANCE AUTOHEAL GROUP
# -------------------------------------

squid_name = "squid"
squid_machine_type = "n1-standard-4"
squid_labels = {
  "data-commons" = "data-commons"
  "department" = "ctds"
  "environment" = "production"
  "sponsor" = "sponsor"
}
squid_target_size = "1"
squid_metadata_startup_script = "../../../modules/compute-group/scripts/squid-install.sh"
squid_hc_check_interval_sec = "5"
squid_hc_timeout_sec = "5"
squid_hc_healthy_threshold = "2"
squid_hc_unhealthy_threshold = "10"
squid_hc_tcp_health_check_port = "3128"

# -------------------------------------
#   SQUID AUTOSCALER
# -------------------------------------

squid_min_replicas = "1"
squid_max_replicas = "10"
squid_cpu_utilization_target = "0.8"
squid_cooldown_period = "300"

# -------------------------------------
#   INTERNAL LOAD BALANCER FOR SQUID
# -------------------------------------

squid_lb_name = "squid-ilb"
squid_lb_health_port = "3128"
squid_lb_ports = ["3128"]
#squid_lb_target_tags = ["squid", "proxy"]
