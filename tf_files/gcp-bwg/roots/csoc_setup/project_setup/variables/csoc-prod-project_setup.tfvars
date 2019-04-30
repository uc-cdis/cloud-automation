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


ssh_ingress_enable_logging = true
ssh_ingress_priority = "1000"
ssh_ingress_direction = "INGRESS"
ssh_ingress_protocol = "tcp"
ssh_ingress_ports = ["22"]
ssh_ingress_source_ranges = ["172.21.1.0/24"]
ssh_ingress_target_tags = ["ssh-in"]

http_ingress_enable_logging = true
http_ingress_priority = "1001"
http_ingress_direction = "INGRESS"
http_ingress_protocol = "tcp"
http_ingress_ports = ["80"]
http_ingress_source_ranges = ["172.21.1.0/24"]
http_ingress_target_tags = ["http-in"]

https_ingress_enable_logging = true
https_ingress_priority = "1002"
https_ingress_direction = "INGRESS"
https_ingress_protocol = "tcp"
https_ingress_ports = ["443"]
https_ingress_source_ranges = ["172.21.1.0/24"]
https_ingress_target_tags = ["https-in"]

project_name = "<new_project_name_here>"
billing_account = "<billing_account_here>"
credential_file = "<credentials>.json"
create_folder = true
set_parent_folder = true
folder = "csoc-production"
region = "us-central1"
organization = "<organization_name_here>"
org_id = "<org_id_here>"
prefix_org_setup = "org_setup_csoc"
prefix_project_setup = "project_setup_csoc"
state_bucket_name = "<tfstate_bucket_here>"
env = "csoc-prod"
