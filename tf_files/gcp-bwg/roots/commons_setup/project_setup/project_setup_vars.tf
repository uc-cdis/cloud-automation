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

variable "csoc_state_bucket_name" {
  description = "Terraform state bucket name in the csoc account. Used to for VPC peering."
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

variable "state_bucket_name" {
  default = "tf-state"
}

variable "region" {
  description = "URL of the GCP region for this subnetwork."
  default     = "us-central1"
}

####### VPC (google_network) info
variable "commons001-dev_private_network_name" {
  default = "my-network"
}

variable "commons001-dev_private_subnet_name" {
  default = "my-subnet"
}

variable "commons001-dev_private_subnet_ip" {
  default = "172.16.0.0/24"
}

variable "commons001-dev_private_region" {
  default = "us-central1"
}

variable "commons001-dev_private_subnet_flow_logs" {
  default = true
}

variable "commons001-dev_private_subnet_private_access" {
  default = false
}

variable "create_vpc_secondary_ranges" {
  default = true
}

variable "commons001-dev_private_subnet_secondary_name1" {
  default = "my-alias-network"
}

variable "commons001-dev_private_subnet_secondary_ip1" {
  default = "10.128.1.0/24"
}

variable "commons001-dev_private_subnet_secondary_name2" {
  default = "my-alias-network"
}

variable "commons001-dev_private_subnet_secondary_ip2" {
  default = "10.128.1.0/24"
}

###### Firewall Rule Info
variable "commons001-dev_ingress_enable_logging" {
  default = true
}

variable "commons001-dev_ingress_priority" {
  default = "1000"
}

variable "commons001-dev_ingress_direction" {
  default = "INGRESS"
}

variable "commons001-dev_ingress_protocol" {
  default = "tcp"
}

variable "commons001-dev_ingress_ports" {
  type = "list"
}

variable "commons001-dev_ingress_source_ranges" {
  type = "list"
}

variable "commons001-dev_ingress_target_tags" {
  type    = "list"
  default = ["commons001-dev-ingress"]
}

###
variable "commons001-dev_egress_enable_logging" {
  default = true
}

variable "commons001-dev_egress_priority" {
  default = "1000"
}

variable "commons001-dev_egress_direction" {
  default = "INGRESS"
}

variable "commons001-dev_egress_protocol" {
  default = "tcp"
}

variable "commons001-dev_egress_ports" {
  type = "list"
}

variable "commons001-dev_egress_destination_ranges" {
  type = "list"
}

variable "commons001-dev_egress_target_tags" {
  type    = "list"
  default = ["commons001-dev-egress"]
}

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
