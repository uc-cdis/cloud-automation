########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info
variable "org_id" {
  description = "GCP Organization ID"
  default     = ""
}

variable "env" {
  description = "Environment variable."
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

######## VPC RELATED VARS
variable "range_name_k8_service" {
  description = "The name for the cluster services."
  default     = "k8-services"
}

variable "ip_cidr_range_k8_service" {
  description = "The IP address range of the services IPs in this cluster."
}

variable "range_name_k8_pod" {
  description = "The name for the cluster pods."
  default     = "k8-pods"
}

variable "ip_cidr_range_k8_pod" {
  description = "The IP address range of the pods IPs in this cluster."

  #default = ""
}

variable "csoc_egress_network_name" {
  description = "Name of the network"
}

variable "csoc_egress_subnet_name" {
  description = "Name of the subnet"
}

variable "csoc_egress_subnet_ip" {
  description = "IP range of the subnet ie. 10.0.1.0/24"
}

variable "csoc_egress_subnet_flow_logs" {
  description = "Whether or not to enable vpc flow logs"
}

variable "csoc_egress_subnet_private_access" {
  description = "Whether or not to enable private access"
}

variable "csoc_ingress_network_name" {
  description = "Name of the network"
}

variable "csoc_ingress_subnet_name" {
  description = "Name of the subnet"
}

variable "csoc_ingress_subnet_ip" {
  description = "IP range of the subnet ie. 10.0.1.0/24"
}

variable "csoc_ingress_subnet_flow_logs" {
  description = "Whether or not to enable vpc flow logs"
}

variable "csoc_ingress_subnet_private_access" {
  description = "Whether or not to enable private access"
}

variable "csoc_private_network_name" {
  description = "Name of the network"
}

variable "csoc_private_subnet_name" {
  description = "Name of the subnet"
}

variable "csoc_private_subnet_ip" {
  description = "IP range of the subnet ie. 10.0.1.0/24"
}

variable "csoc_private_subnet_flow_logs" {
  description = "Whether or not to enable vpc flow logs"
}

variable "csoc_private_subnet_private_access" {
  description = "Whether or not to enable private access"
}

#########Variables to create the subnets for each vpc#######

variable "csoc_egress_subnet_octet1" {
  description = "first segment of the ip range for vpc subnet"
}

variable "csoc_egress_subnet_octet2" {
  description = "second segment of the ip range for vpc subnet"
}

variable "csoc_egress_subnet_octet3" {
  description = "third segment of the ip range for vpc subnet"
}

variable "csoc_egress_subnet_octet4" {
  description = "fourth segment of the ip range for vpc subnet"
}

variable "csoc_egress_subnet_mask" {
  description = "subnet mask of the vpc subnet"
}

variable "csoc_egress_region" {
  description = "region vpc resides in"
}

variable "csoc_private_subnet_octet1" {
  description = "first segment of the ip range for vpc subnet"
}

variable "csoc_private_subnet_octet2" {
  description = "second segment of the ip range for vpc subnet"
}

variable "csoc_private_subnet_octet3" {
  description = "third segment of the ip range for vpc subnet"
}

variable "csoc_private_subnet_octet4" {
  description = "fourth segment of the ip range for vpc subnet"
}

variable "csoc_private_subnet_mask" {
  description = "subnet mask of the vpc subnet"
}

variable "csoc_private_region" {
  description = "region vpc resides in"
}

variable "csoc_ingress_subnet_octet1" {
  description = "first segment of the ip range for vpc subnet"
}

variable "csoc_ingress_subnet_octet2" {
  description = "second segment of the ip range for vpc subnet"
}

variable "csoc_ingress_subnet_octet3" {
  description = "third segment of the ip range for vpc subnet"
}

variable "csoc_ingress_subnet_octet4" {
  description = "fourth segment of the ip range for vpc subnet"
}

variable "csoc_ingress_subnet_mask" {
  description = "subnet mask of the vpc subnet"
}

variable "csoc_ingress_region" {
  description = "region vpc resides in"
}

############ Firewall Rule Relate VARS ############################################
// VPC-CSOC-EGRESS Variables
variable "csoc_egress_inboud_protocol" {}

variable "csoc_egress_inboud_ports" {
  type = "list"
}

variable "csoc_egress_inboud_tags" {
  type = "list"
}

variable "csoc_egress_outbound_priority" {}
variable "csoc_egress_outbound_protocol" {}

variable "csoc_egress_outbound_ports" {
  type = "list"
}

variable "csoc_egress_outbound_target_tags" {
  type = "list"
}

variable "csoc_egress_outbound_deny_all_priority" {}
variable "csoc_egress_outbound_deny_all_protocol" {}

// VPC-CSOC-INGRESS Variables
variable "csoc_ingress_inbound_ssh_protocol" {}

variable "csoc_ingress_inbound_ssh_ports" {
  type = "list"
}

variable "csoc_ingress_inbound_ssh_tags" {
  type = "list"
}

variable "csoc_ingress_inbound_openvpn_protocol" {}

variable "csoc_ingress_inbound_openvpn_ports" {
  type = "list"
}

variable "csoc_ingress_inbound_openvpn_tags" {
  type = "list"
}

variable "csoc_ingress_outbound_proxy_priority" {}
variable "csoc_ingress_outbound_proxy_protocol" {}

variable "csoc_ingress_outbound_proxy_ports" {
  type = "list"
}

variable "csoc_ingress_outbound_proxy_tags" {
  type = "list"
}

variable "csoc_ingress_outbound_deny_all_priority" {}
variable "csoc_ingress_outbound_deny_all_protocol" {}

// VPC-CSOC-PRIVATE Variables
variable "csoc_private_inbound_ssh_protocol" {}

variable "csoc_private_inbound_ssh_ports" {
  type = "list"
}

variable "csoc_private_inbound_ssh_target_tags" {
  type = "list"
}

variable "csoc_private_inbound_qualys_udp_protocol" {}

variable "csoc_private_inbound_qualys_udp_target_tags" {
  type = "list"
}

variable "csoc_private_inbound_qualys_tcp_protocol" {}

variable "csoc_private_inbound_qualys_tcp_target_tags" {
  type = "list"
}

variable "csoc_private_outbound_qualys_udp_protocol" {}

variable "csoc_private_outbound_qualys_udp_target_tags" {
  type = "list"
}

variable "csoc_private_outbound_qualys_tcp_protocol" {}

variable "csoc_private_outbound_qualys_tcp_target_tags" {
  type = "list"
}

variable "csoc_private_outbound_ssh_protocol" {}

variable "csoc_private_outbound_ssh_ports" {
  type = "list"
}

variable "csoc_private_outbound_ssh_target_tags" {
  type = "list"
}

variable "csoc_private_outbound_qualys_update_protocol" {}

variable "csoc_private_outbound_qualys_update_ports" {
  type = "list"
}

variable "csoc_private_outbound_qualys_update_target_tags" {
  type = "list"
}

variable "csoc_private_outbound_proxy_priority" {}
variable "csoc_private_outbound_proxy_protocol" {}

variable "csoc_private_outbound_proxy_ports" {
  type = "list"
}

variable "csoc_private_outbound_proxy_target_tags" {
  type = "list"
}

variable "csoc_private_outbound_deny_all_priority" {}
variable "csoc_private_outbound_deny_all_protocol" {}

variable "ssh_ingress_enable_logging" {
  description = "Whether or not to enable logging for inbound ssh firewall rule"
}

variable "ssh_ingress_priority" {
  description = "priority level for inbound ssh firewall rule"
}

variable "ssh_ingress_direction" {
  description = "Direction for firewall rule [inbound or outbound]"
}

variable "ssh_ingress_protocol" {
  description = "Protocol for port [TCP|UDP]"
}

variable "ssh_ingress_ports" {
  type        = "list"
  description = "Port number to open"
}

variable "ssh_ingress_source_ranges" {
  type        = "list"
  description = "source ip ranges for firewall rule"
}

variable "ssh_ingress_target_tags" {
  type        = "list"
  description = "Tag to identify systems allowed to use this rule"
}

variable "http_ingress_enable_logging" {
  description = "Whether or not to enable logging for inbound http firewall rule"
}

variable "http_ingress_priority" {
  description = "priority level for inbound http firewall rule"
}

variable "http_ingress_direction" {
  description = "Direction for firewall rule [inbound or outbound]"
}

variable "http_ingress_protocol" {
  description = "Protocol for port [TCP|UDP]"
}

variable "http_ingress_ports" {
  type        = "list"
  description = "Port number to open"
}

variable "http_ingress_source_ranges" {
  type        = "list"
  description = "source ip ranges for firewall rule"
}

variable "http_ingress_target_tags" {
  type        = "list"
  description = "Tag to identify systems allowed to use this rule"
}

variable "https_ingress_enable_logging" {
  description = "Whether or not to enable logging for inbound https firewall rule"
}

variable "https_ingress_priority" {
  description = "priority level for inbound https firewall rule"
}

variable "https_ingress_direction" {
  description = "Direction for firewall rule [inbound or outbound]"
}

variable "https_ingress_protocol" {
  description = "Protocol for port [TCP|UDP]"
}

variable "https_ingress_ports" {
  type        = "list"
  description = "Port number to open"
}

variable "https_ingress_source_ranges" {
  type        = "list"
  description = "source ip ranges for firewall rule"
}

variable "https_ingress_target_tags" {
  type        = "list"
  description = "Tag to identify systems allowed to use this rule"
}

######## VPC PEERING RELATED VARS
variable "peer_auto_create_routes" {
  description = "Whether or not to autocreate the routes for the vpc peer"
  default     = true
}
