########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info
project_name = "jca-uchi-tf-csoc"
billing_account = "01A7C1-F7ECC5-A7181E"
credential_file = "../credentials.json"
create_folder = true
set_parent_folder = true
folder = "csoc-production"
region = "us-central1"
organization = "prorelativity.com"
org_id = "575228741867"
prefix_org_setup = "org_setup_csoc"
prefix_project_setup = "org_setup_csoc"
prefix_org_policies = "org_policies"

state_bucket_name = "jca-uchi-tf-state"
env = "csoc-prod"

#### Uncomment this if not using our makefiles
#terraform_workspace = "csoc_setup"


####VPC (google_network) info
create_vpc_secondary_ranges = false
ip_cidr_range_k8_service = "10.170.80.0/20"
ip_cidr_range_k8_pod = "10.56.0.0/14"


csoc_egress_network_name = "jca-uchi-tf-csoc-egress"
csoc_egress_subnet_name = "csoc-egress-kubecontrol"
csoc_egress_region = "us-central1"
csoc_egress_subnet_ip = "172.29.31.0/24"
csoc_egress_subnet_octet1 = "172"
csoc_egress_subnet_octet2 = "29"
csoc_egress_subnet_octet3 = "31"
csoc_egress_subnet_octet4 = "0"
csoc_egress_subnet_mask = "24"
csoc_egress_subnet_flow_logs = true
csoc_egress_subnet_private_access = false

csoc_ingress_network_name = "jca-uchi-tf-csoc-ingress"
csoc_ingress_subnet_name = "csoc-ingress-kubecontrol"
csoc_ingress_region = "us-central1"
csoc_ingress_subnet_ip = "172.29.30.0/24"
csoc_ingress_subnet_octet1 = "172"
csoc_ingress_subnet_octet2 = "29"
csoc_ingress_subnet_octet3 = "30"
csoc_ingress_subnet_octet4 = "0"
csoc_ingress_subnet_mask = "24"
csoc_ingress_subnet_flow_logs = true
csoc_ingress_subnet_private_access = false

csoc_private_network_name = "jca-uchi-tf-csoc-private"
csoc_private_subnet_name = "csoc-private-kubecontrol"
csoc_private_region = "us-central1"
csoc_private_subnet_ip = "172.29.29.0/24"
csoc_private_subnet_octet1 = "172"
csoc_private_subnet_octet2 = "29"
csoc_private_subnet_octet3 = "29"
csoc_private_subnet_octet4 = "0"
csoc_private_subnet_mask = "24"
csoc_private_subnet_flow_logs = true
csoc_private_subnet_private_access = false

###### Firewall Rule Info
ssh_ingress_enable_logging = true
ssh_ingress_priority = "1000"
ssh_ingress_direction = "INGRESS"
ssh_ingress_protocol = "tcp"
ssh_ingress_ports = ["22"]
#ssh_ingress_source_ranges = ["172.21.1.0/24"]
ssh_ingress_target_tags = ["ssh-in"]

http_ingress_enable_logging = true
http_ingress_priority = "1001"
http_ingress_direction = "INGRESS"
http_ingress_protocol = "tcp"
http_ingress_ports = ["80"]
#http_ingress_source_ranges = ["172.21.1.0/24"]
http_ingress_target_tags = ["http-in"]

https_ingress_enable_logging = true
https_ingress_priority = "1002"
https_ingress_direction = "INGRESS"
https_ingress_protocol = "tcp"
https_ingress_ports = ["443"]
#https_ingress_source_ranges = ["172.21.1.0/24"]
https_ingress_target_tags = ["https-in"]

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
csoc_ingress_inbound_ssh_tags = ["ssh-in-cscoc-ingress"]

csoc_ingress_inbound_openvpn_protocol = "TCP" 
csoc_ingress_inbound_openvpn_ports = ["1194", "443"] 
csoc_ingress_inbound_openvpn_tags = ["openvpn"] 

csoc_ingress_outbound_proxy_priority = "900" 
csoc_ingress_outbound_proxy_protocol = "TCP" 
csoc_ingress_outbound_proxy_ports = ["3128"]
csoc_ingress_outbound_proxy_tags = ["proxy-access"] 

csoc_ingress_outbound_deny_all_priority = "65534" 
csoc_ingress_outbound_deny_all_protocol = "ALL" 

inbound_from_private_name = "csoc-ingress-from-csoc-private"
inbound_from_private_network_name = "jca-uchi-tf-csoc-ingress"
inbound_from_private_source_ranges = "172.29.29.0/24"
inbound_from_private_target_tags = "csoc-ingress-from-csoc-private"
inbound_from_private_protocol = "tcp"

// VPC-CSOC-PRIVATE Variables
csoc_private_inbound_ssh_protocol = "TCP" 
csoc_private_inbound_ssh_ports = ["22"]
csoc_private_inbound_ssh_target_tags = ["ssh-in-csoc-private"]

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

inbound_from_ingress_name = "csoc-private-from-csoc-ingress"
inbound_from_ingress_network_name = "jca-uchi-tf-csoc-private"
inbound_from_ingress_source_ranges = ["172.29.30.0/24"]
inbound_from_ingress_target_tags = ["csoc-private-from-csoc-ingress"]
inbound_from_ingress_protocol = "tcp"
inbound_from_ingress_ports = ["1-65535"]

inbound_from_commons001_name = "csoc-private-from-commons001"
inbound_from_commons001_network_name = "commons001-dev-private"
inbound_from_commons001_source_ranges = ["172.30.30.0/24"]
inbound_from_commons001_target_tags = ["csoc-private-from-commons001"]
inbound_from_commons001_protocol = "tcp"
inbound_from_commons001_ports = ["1-65535"]

inbound_to_commons001_network_name = "commons001-dev-private"
inbound_to_commons001_ports = ["1-65535"]
inbound_to_commons001_source_ranges = ["0.0.0.0/0"]
inbound_to_commons001_name = "inbound-to-commons001"
inbound_to_commons001_target_tags = ["inbound-to-commons001"]
inbound_to_commons001_protocol = "tcp"

inbound_to_private_name = "inbound-to-private"
inbound_to_private_target_tags = ["inbound-to-private"]
inbound_to_private_network_name  = "jca-uchi-tf-csoc-private"
inbound_to_private_source_ranges = ["0.0.0.0/0"]
inbound_to_private_protocol = "tcp"

inbound_to_ingress_ports = ["1-65535"]
inbound_to_ingress_network_name = "jca-uchi-tf-csoc-ingress"
inbound_to_ingress_name = "inbound-to-ingress"
inbound_to_ingress_source_ranges = ["0.0.0.0/0"]
inbound_to_ingress_target_tags = ["inbound-to-ingress"]
inbound_to_ingress_protocol = "tcp"

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
outbound_from_gke_destination_ranges = ["172.29.30.0/24", "172.29.29.0/24"]
outbound_from_gke_target_tags = ["outbound-from-gke"]
outbound_from_gke_ports = ["1-65535"]
outbound_from_gke_protocol = "tcp"
outbound_from_gke_enable_logging = true
outbound_from_gke_priority = "1000"

ssh_ingress_source_ranges = ["0.0.0.0/0"]
csoc_ingress_priority = "1000"
csoc_ingress_enable_logging = true
https_ingress_source_ranges  = ["0.0.0.0/0"]
http_ingress_source_ranges = ["0.0.0.0/0"]

###### VPC Peering info
peer_auto_create_routes = true


google_apis_route = "google-apis"

