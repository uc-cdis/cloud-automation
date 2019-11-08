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

# BUCKET NAME THAT HOSTS TERRAFORM STATE
state_bucket_name = "terraform-state--426447812"
state_project_name = "tf-project-factory-3537"

# FOLDERS INSIDE BUCKETS
prefix_org_setup = "org_setup_csoc2"
prefix_project_setup = "project_setup_csoc2"
prefix_platform_setup = "platform_setup_csoc2"
prefix_app_setup = "app_setup_csoc2"
prefix_org_policies = "org_policies_csoc2"

### Uncomment this if not using our makefiles
#terraform_workspace = "csoc_setup"

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
org_iam_externalipaccess = [""]

#### Role Bindings to group and user accounts
org_administrator_org_binding=["group:org_admins@prorelativity.com"]
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

organization = "prorelativity.com"
org_id = "575228741867"
billing_account = "018556-CE0EB9-0511A3"
credential_file = "~/terraform/project-factory-4404.json"
env = "csoc"

# -------------------------------------
#   Folder Variables
# -------------------------------------

create_folder = true
set_parent_folder = true
folder = "csoc2"

# -------------------------------------
#   Project Variables
# -------------------------------------

project_name = "csoc-prod2"
region = "us-central1"

# ------------------------------------------------------------------
#
#   PROJECT SETUP
#
# ------------------------------------------------------------------
# -------------------------------------
#   VPC Variables
# -------------------------------------

# VPC NETWORK
csoc_egress_network_name = "csoc-egress"
csoc_ingress_network_name = "csoc-ingress"
csoc_private_network_name = "csoc-private"

# VPC SUBNETWORK
csoc_egress_subnet_name = "csoc-egress-squid"
csoc_egress_subnet_ip = "10.128.67.0/24"
csoc_egress_region = "us-central1"
csoc_egress_subnet_flow_logs = true
csoc_egress_subnet_private_access = false

csoc_ingress_subnet_name = "csoc-ingress-vpn"
csoc_ingress_subnet_ip = "10.128.69.0/24"
csoc_ingress_region = "us-central1"
csoc_ingress_subnet_flow_logs = true
csoc_ingress_subnet_private_access = false

csoc_private_subnet_name = "csoc-private-admin"
csoc_private_subnet_ip = "10.128.65.0/24"
csoc_private_region = "us-central1"
csoc_private_subnet_flow_logs = true
csoc_private_subnet_private_access = false

#VPC (google_network) info
create_vpc_secondary_ranges = false
ip_cidr_range_k8_service = "<K8_service_ip_range>"
ip_cidr_range_k8_pod = "<K8_pod_ip_range>"

# VPC PEERING INFORMATION
peer_auto_create_routes = true
google_apis_route = "google-apis"

###### Cloud NAT
router_name = "csoc-cloud-router"
nat_name = "csoc-cloud-nat"
nat_ip_allocate_option = "MANUAL_ONLY"

# -------------------------------------
#   Firewall Variables
# -------------------------------------

#ssh_ingress_enable_logging = true
#ssh_ingress_priority = "1000"
#ssh_ingress_direction = "INGRESS"
#ssh_ingress_protocol = "tcp"
#ssh_ingress_ports = ["22"]
#ssh_ingress_source_ranges = ["172.21.1.0/24"]
#ssh_ingress_target_tags = ["ssh-in"]

#http_ingress_enable_logging = true
#http_ingress_priority = "1001"
#http_ingress_direction = "INGRESS"
#http_ingress_protocol = "tcp"
#http_ingress_ports = ["80"]
#http_ingress_source_ranges = ["172.21.1.0/24"]
#http_ingress_target_tags = ["http-in"]

#https_ingress_enable_logging = true
#https_ingress_priority = "1002"
#https_ingress_direction = "INGRESS"
#https_ingress_protocol = "tcp"
#https_ingress_ports = ["443"]
#https_ingress_source_ranges = ["172.21.1.0/24"]
#https_ingress_target_tags = ["https-in"]

// VPC-CSOC-EGRESS Variables
csoc_egress_inboud_protocol = "TCP"
csoc_egress_inboud_ports = ["3128"]
csoc_egress_inboud_tags = ["proxy"]

csoc_egress_outbound_priority = "900"
csoc_egress_outbound_protocol = "TCP"
csoc_egress_outbound_ports = ["80", "443"]
csoc_egress_outbound_target_tags = ["web-access"]

csoc_egress_outbound_deny_all_priority = "65534"
csoc_egress_outbound_deny_all_protocol = "ALL"

// VPC-CSOC-INGRESS Variables
csoc_ingress_inbound_ssh_protocol = "TCP"
csoc_ingress_inbound_ssh_ports = ["22"]
csoc_ingress_inbound_ssh_tags = ["ssh-in-csoc-ingress"]

csoc_ingress_inbound_openvpn_protocol = "TCP"
csoc_ingress_inbound_openvpn_ports = ["1194", "443"]
csoc_ingress_inbound_openvpn_tags = ["openvpn"]

csoc_ingress_outbound_proxy_priority = "900"
csoc_ingress_outbound_proxy_protocol = "TCP"
csoc_ingress_outbound_proxy_ports = ["3128"]
csoc_ingress_outbound_proxy_tags = ["proxy-access"]

csoc_ingress_outbound_ssh_ports = ["22"]
csoc_ingress_outbound_ssh_tag = ["outbound-ssh"]

csoc_ingress_outbound_deny_all_priority = "65534"
csoc_ingress_outbound_deny_all_protocol = "ALL"

// VPC-CSOC-PRIVATE Variables
csoc_private_inbound_ssh_protocol = "TCP"
csoc_private_inbound_ssh_ports = ["22"]
csoc_private_inbound_ssh_target_tags = ["csoc-private-ssh-in"]

csoc_private_inbound_qualys_udp_protocol = "UDP"
csoc_private_inbound_qualys_udp_target_tags = ["qualys-ingress-udp"]

csoc_private_inbound_qualys_tcp_protocol = "TCP"
csoc_private_inbound_qualys_tcp_target_tags = ["qualys-inbound-tcp"]

csoc_private_outbound_qualys_udp_protocol = "UDP"
csoc_private_outbound_qualys_udp_target_tags = ["qualys-egress-udp"]

csoc_private_outbound_qualys_tcp_protocol = "TCP"
csoc_private_outbound_qualys_tcp_target_tags = ["qualys-egress-tcp"]

csoc_private_outbound_ssh_protocol = "TCP"
csoc_private_outbound_ssh_ports = ["22"]
csoc_private_outbound_ssh_target_tags = ["ssh-egress-tcp"]

csoc_private_outbound_qualys_update_protocol = "TCP"
csoc_private_outbound_qualys_update_ports = ["443"]
csoc_private_outbound_qualys_update_target_tags = ["qualys-egress-update"]

csoc_private_outbound_proxy_priority = "900"
csoc_private_outbound_proxy_protocol = "TCP"
csoc_private_outbound_proxy_ports = ["3128"]
csoc_private_outbound_proxy_target_tags = ["proxy-access"]

csoc_private_outbound_deny_all_priority = "65534"
csoc_private_outbound_deny_all_protocol = "ALL"

#inbound_from_ingress_name = "csoc-private-from-csoc-ingress"
#inbound_from_ingress_network_name = "jca-uchi-csoc-private"
#inbound_from_ingress_source_ranges = ["172.29.30.0/24"]
#inbound_from_ingress_target_tags = ["csoc-private-from-csoc-ingress"]
#inbound_from_ingress_protocol = "tcp"
#inbound_from_ingress_ports = ["1-65535"]

#inbound_from_commons001_name = "csoc-private-from-commons001"
#inbound_from_commons001_network_name = "commons001-dev-private"
#inbound_from_commons001_source_ranges = ["172.30.30.0/24"]
#inbound_from_commons001_target_tags = ["csoc-private-from-commons001"]
#inbound_from_commons001_protocol = "tcp"
#inbound_from_commons001_ports = ["1-65535"]

#inbound_to_commons001_network_name = "commons001-dev-private"
#inbound_to_commons001_ports = ["1-65535"]
#inbound_to_commons001_source_ranges = ["0.0.0.0/0"]
#inbound_to_commons001_name = "inbound-to-commons001"
#inbound_to_commons001_target_tags = ["inbound-to-commons001"]
#inbound_to_commons001_protocol = "tcp"

#inbound_to_private_name = "inbound-to-private"
#inbound_to_private_target_tags = ["inbound-to-private"]
#inbound_to_private_network_name  = "jca-uchi-csoc-private"
#inbound_to_private_source_ranges = ["0.0.0.0/0"]
#inbound_to_private_protocol = "tcp"

#inbound_to_ingress_ports = ["1-65535"]
#inbound_to_ingress_network_name = "jca-uchi-csoc-ingress"
#inbound_to_ingress_name = "inbound-to-ingress"
#inbound_to_ingress_source_ranges = ["0.0.0.0/0"]
#inbound_to_ingress_target_tags = ["inbound-to-ingress"]
#inbound_to_ingress_protocol = "tcp"

inbound_from_gke_name = "inbound-from-gke"
inbound_from_gke_network_name = ""
inbound_from_gke_source_ranges = ["172.16.0.0/28"]
inbound_from_gke_target_tags = ["inbound-from-gke-name"]
inbound_from_gke_ports = ["1-65535"]
inbound_from_gke_protocol = "tcp"
inbound_from_gke_enable_logging = true
inbound_from_gke_priority = "1000"

outbound_from_gke_name = "outbound-from-gke-fw"
outbound_from_gke_network_name = ""
outbound_from_gke_destination_ranges = ["0.0.0.0/0"]
outbound_from_gke_target_tags = ["outbound-from-gke"]
outbound_from_gke_ports = ["443","10250"]
outbound_from_gke_protocol = "tcp"
outbound_from_gke_enable_logging = true
outbound_from_gke_priority = "1000"

ssh_ingress_source_ranges = ["0.0.0.0/0"]
csoc_ingress_priority = "1000"
csoc_ingress_enable_logging = true
https_ingress_source_ranges  = ["0.0.0.0/0"]
http_ingress_source_ranges = ["0.0.0.0/0"]

# ------------------------------------------------------------------
#
#   APPLICATION SETUP
#
# ------------------------------------------------------------------
# -------------------------------------
#   AdminVM Instance
# -------------------------------------

instance_name = "commons-vm-admin-vm"
labels = {
  "data-commons" = "data-commons"
  "department" = "ctds"
  "environment" = "production"
  "sponsor" = "sponsor"
}

# -------------------------------------
#   Bastion Instance
# -------------------------------------

#bastion_name = "bastionvm"


# -------------------------------------
#   OPENVPN MANAGED INSTANCE GROUP
# -------------------------------------

openvpn_name = "openvpn"
openvpn_machine_type = "n1-standard-2"
openvpn_target_size = "2"
openvpn_metadata_startup_script = "../../../modules/compute-group/scripts/openVPN-Install.sh"
openvpn_labels = {
  "data-commons" = "data-commons"
  "department" = "ctds"
  "environment" = "production"
  "sponsor" = "sponsor"
}

# -------------------------------------
#   SQUID MANAGED INSTANCE AUTOHEAL GROUP
# -------------------------------------

squid_name = "squid"
squid_machine_type = "n1-standard-2"
squid_target_size = "2"
squid_metadata_startup_script = "../../../modules/compute-group/scripts/squid-install.sh"
squid_hc_check_interval_sec = "5"
squid_hc_timeout_sec = "5"
squid_hc_healthy_threshold = "2"
squid_hc_unhealthy_threshold = "10"
squid_hc_tcp_health_check_port = "3128"
squid_labels = {
  "data-commons" = "data-commons"
  "department" = "ctds"
  "environment" = "production"
  "sponsor" = "sponsor"
}

# -------------------------------------
#   OPENVPN AUTOSCALER
# -------------------------------------

openvpn_min_replicas = "2"
openvpn_max_replicas = "10"
openvpn_cpu_utilization_target = "0.8"
openvpn_cooldown_period = "300"

# -------------------------------------
#   SQUID AUTOSCALER
# -------------------------------------

squid_min_replicas = "2"
squid_max_replicas = "10"
squid_cpu_utilization_target = "0.8"
squid_cooldown_period = "300"


# -------------------------------------
#   OPENVPN AUTOSCALER
# -------------------------------------

#openvpn_min_replicas = "1"
#openvpn_max_replicas = "3"
#openvpn_cpu_utilization_target = "0.8"
#openvpn_cooldown_period = "300"

# -------------------------------------
#   SQUID AUTOSCALER
# -------------------------------------

#squid_min_replicas = "1"
#squid_max_replicas = "3"
#squid_cpu_utilization_target = "0.8"
#squid_cooldown_period = "300"

# -------------------------------------
#   EXTERNAL LOAD BALANCER FOR OPENVPN
# ------------------------------------

openvpn_lb_port = "1194"

# -------------------------------------
#   INTERNAL LOAD BALANCER FOR SQUID
# -------------------------------------

squid_lb_name = "squid-ilb"
squid_lb_health_port = "3128"
squid_lb_ports = ["3128"]
squid_lb_target_tags = ["squid", "proxy"]

# -------------------------------------
#   Compute Instance Variables
# -------------------------------------
# SSH INFORMATION
ssh_user = "astrong"
ssh_key_pub = "~/terraform/astrong_rsa.pem.pub"
ssh_key = "~/terraform/astrong_rsa.pem"

# INSTANCE IMAGES AND SIZE
image_name = "ubuntu-1804-lts"
count_compute = "1"
count_start  = "1"
machine_type_dev = "g1-small"
machine_type_prod = "n1-standard-1"

# Tags and Label Variables
#compute_tags = ["csoc-ingress-from-csoc-private", "csoc-ingress-to-csoc-private", "csoc-private-from-commons001", "csoc-private-from-csoc-ingress", "ssh-in-csoc-private","inbound-to-commons001","web-access"]
#bastion_compute_tags = ["csoc-ingress-from-csoc-private", "csoc-ingress-to-csoc-private", "csoc-private-from-commons001","ssh-in-csoc-ingress","web-access"]
compute_labels = {
    "department"  = "ctds"
    "sponsor"     = "sponsor"
    "envrionment" = "development"
    "datacommons" = "commons"
  }

# Boot-disk Variables
size = "15"
type = "pd-standard"
auto_delete = "true"

# Network Interface Variables
subnetwork_name = "csoc-private-kubecontrol"
ingress_subnetwork_name = "csoc-ingress-kubecontrol"

# Service Account block
  scopes = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/service.management",
    "https://www.googleapis.com/auth/devstorage.full_control",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
#scopes = [
#  "userinfo-email", "compute-ro", "storage-ro", "cloud-platform", "service.management"
#]

# Scheduling
automatic_restart = "true"
on_host_maintenance = "MIGRATE"

# -------------------------------------
#   Cloud Bucket Variables for Stackdriver Org Sink
# -------------------------------------

bucket_data_access_logs = "bucket_access_logs_aws_9876"
bucket_activity_logs = "bucket_activity_logs_aws_9876"

bucket_activity_logs_labels = {
    "department"  = "ctds"
    "sponsor"     = "sponsor"
    "envrionment" = "development"
    "datacommons" = "commons"
}
bucket_data_access_logs_labels = {
    "department"  = "ctds"
    "sponsor"     = "sponsor"
    "envrionment" = "development"
    "datacommons" = "commons"
}

# -------------------------------------
#   Stackdriver Org Sink Variables
# -------------------------------------

data_access_sink_name = "data_access_csoc_logs"
activity_sink_name = "activity_csoc_logs"
