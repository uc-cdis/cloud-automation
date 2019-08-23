variable "network_name" {
  description = "The name of the network being created"
}
variable "project_id" {
  description = "The ID of the project where this VPC will be created"
}
/*
variable "region" {
  description = "URL of the GCP region for this subnetwork."
}
*/
variable "auto_create_subnetworks" {
  description = "Set to false to use custom network. If set to true will use default network."
  default = "false"
}

variable "routing_mode" {
  type        = "string"
  default     = "REGIONAL"
  description = "The network routing mode (default 'GLOBAL')"
}

variable "delete_default_routes" {
  description = "default routes (0.0.0.0/0) will be deleted immediately after network creation. "
  default = "true"
}

variable "subnet_flow_logs" {
  description = "Whether to enable flow logging for this subnetwork."
  default = "true"
}

variable "subnets" {
  type        = "list"
  description = "The list of subnets being created"
}

variable "secondary_ranges" {
  type        = "map"
  description = "Secondary ranges that will be used in some of the subnets"
}

variable "create_vpc_secondary_ranges" {
  description = "Whether or not to create secondary ranges for vpc subnets (alias)"
  default = true
}


/*variable "google_apis_route" {
  description = "Route to restricted Google APIs"
}
*/

variable "routes" {
  type        = "list"
  description = "List of routes being created in this VPC"
  default     = []
}
