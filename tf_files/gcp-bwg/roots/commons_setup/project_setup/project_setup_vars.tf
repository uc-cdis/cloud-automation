########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info

variable "env" {
  description = "The name of the customer project we are working on or team we are building for."
  default     = "PROD"
}

variable "tf_state_project_setup_csoc" {
  description = "TF State bucket name that hosts project setup VPC self links."
}

variable "state_bucket_name_csoc" {
  description = "Terraform state bucket name in the csoc2 account. Used to for VPC peering."
}

variable "org_id" {
  description = "GCP Organization ID"
  default     = ""
}

variable "project_id" {
  description = "The ID of the project in which the resource belongs."
  default     = ""
}

variable "project_name" {
  description = "Name of the GCP Project"
  default     = "my-first-project"
}

variable "billing_account" {
  default = ""
}

variable "credential_file" {
  default = "credentials.json"
}

variable "terraform_workspace" {
  default = "my-workspace"
}

variable "organization" {
  description = "The name of the Organization."
  default     = "prorelativity.com"
}

variable "folder" {
  default = "Production"
}

variable "prefix" {
  default = "project_setup"
}

variable "prefix_org_setup" {
  default = "org_setup"
}

variable "prefix_project_setup" {
  default = "project_setup"
}

variable "prefix_project_setup_csoc" {
  default = "project_setup_csoc"
}

variable "state_bucket_name" {
  default = "tf-state"
}

variable "region" {
  description = "URL of the GCP region for this subnetwork."
  default     = "us-central1"
}

####### VPC (google_network) info
variable "commons_private_network_name" {
  default = "my-network"
}

variable "commons_private_subnet_name" {
  default = "my-subnet"
}

variable "commons_private_subnet_ip" {
  default = "172.16.0.0/24"
}

variable "commons_private_region" {
  default = "us-central1"
}

variable "commons_private_subnet_flow_logs" {
  default = true
}

variable "commons_private_subnet_private_access" {
  default = false
}

variable "create_vpc_secondary_ranges" {
  default = true
}

variable "commons_private_subnet_secondary_name1" {
  default = "my-alias-network"
}

variable "commons_private_subnet_secondary_ip1" {
  default = "10.128.1.0/24"
}

variable "commons_private_subnet_secondary_name2" {
  default = "my-alias-network"
}

variable "commons_private_subnet_secondary_ip2" {
  default = "10.128.1.0/24"
}

###### Firewall Rule Info
variable "commons_ingress_enable_logging" {
  default = true
}

variable "commons_ingress_priority" {
  default = "1000"
}

variable "commons_ingress_direction" {
  default = "INGRESS"
}

variable "commons_ingress_protocol" {
  default = "tcp"
}

#variable "commons_ingress_ports" {
#  type = "list"
#}

#variable "commons_ingress_source_ranges" {
#  type = "list"
#}

variable "commons_ingress_target_tags" {
  type    = "list"
  default = ["commons-ingress"]
}

###
variable "commons_egress_enable_logging" {
  default = true
}

variable "commons_egress_priority" {
  default = "1000"
}

variable "commons_egress_direction" {
  default = "INGRESS"
}

variable "commons_egress_protocol" {
  default = "tcp"
}

#variable "commons_egress_ports" {
#  type = "list"
#}

#variable "commons_egress_destination_ranges" {
#  type = "list"
#}

variable "commons_egress_target_tags" {
  type    = "list"
  default = ["commons-egress"]
}
/*
variable "outbound_from_gke_name" {}
variable "outbound_from_gke_network_name" {}

variable "outbound_from_gke_destination_ranges" {
  type = "list"
}

variable "outbound_from_gke_target_tags" {
  type = "list"
}

variable "outbound_from_gke_ports" {
  type = "list"
}

variable "outbound_from_gke_protocol" {}
variable "outbound_from_gke_enable_logging" {}
variable "outbound_from_gke_priority" {}


variable "inbound_to_commons_name" {}
variable "inbound_to_commons_network_name" {}

variable "inbound_to_commons_source_ranges" {
  type = "list"
}

variable "inbound_to_commons_target_tags" {
  type = "list"
}

variable "inbound_to_commons_ports" {
  type = "list"
}

variable "inbound_to_commons_protocol" {}
variable "inbound_to_commons_enable_logging" {}
variable "inbound_to_commons_priority" {}

variable "outbound_from_commons_name" {}
variable "outbound_from_commons_network_name" {}

variable "outbound_from_commons_destination_ranges" {
  type = "list"
}

variable "outbound_from_commons_target_tags" {
  type = "list"
}

variable "outbound_from_commons_ports" {
  type = "list"
}

variable "outbound_from_commons_protocol" {}
variable "outbound_from_commons_enable_logging" {}
variable "outbound_from_commons_priority" {}

variable "inbound_from_gke_name" {}
variable "inbound_from_gke_network_name" {}

variable "inbound_from_gke_source_ranges" {
  type = "list"
}

variable "inbound_from_gke_target_tags" {
  type = "list"
}

variable "inbound_from_gke_ports" {
  type = "list"
}

variable "inbound_from_gke_protocol" {}
variable "inbound_from_gke_enable_logging" {}
variable "inbound_from_gke_priority" {}
*/
variable "inbound_proxy_port_enable_logging" {
  default     = true
  description = "Enable firewall logging."
}

variable "inbound_proxy_port_priority" {
  description = "Firewall priority."
}

variable "inbound_proxy_port_name" {}

variable "inbound_proxy_port_protocl" {
  default = "TCP"
}

variable "inbound_proxy_port_ports" {
  type = "list"
}

variable "egress_allow_proxy_mig_enable_logging" {
  default = true
}

variable "egress_allow_proxy_mig_direction" {
  default = "EGRESS"
}

variable "egress_allow_proxy_mig_destination" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "egress_allow_proxy_mig_priority" {}
variable "egress_allow_proxy_mig_name" {}
variable "egress_allow_proxy_mig_protocol" {}

variable "egress_allow_proxy_enable_logging" {
  default = true
}

variable "egress_allow_proxy_direction" {
  default = "EGRESS"
}

variable "egress_allow_proxy_priority" {}
variable "egress_allow_proxy_name" {}
variable "egress_allow_proxy_protocol" {}

variable "egress_allow_proxy_ports" {
  type = "list"
}

####### DENY ALL FIREWALL RULE
variable "egress_deny_all_priority" {}

variable "egress_deny_all_name" {}
variable "egress_deny_all_protocol" {}

####### VPC Peering info
variable "peer_auto_create_routes" {
  default = true
}

variable "google_apis_route" {
  description = "Route to restricted Google APIs"
}

variable "routes" {
  type        = "list"
  description = "List of routes being created in this VPC"
  default     = []
}
