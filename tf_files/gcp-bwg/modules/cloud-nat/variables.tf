variable "router_name" {
  description = "The name of the router in which this NAT will be configured. Changing this forces a new NAT to be created."
  default     = "cloud-router"
}

variable "region" {
  description = "The region this NAT's router sits in."
  default     = "us-central1"
}

variable "project_id" {
  description = "The ID of the project in which the resource belongs."
}

variable "nat_name" {
  description = "A unique name for Cloud NAT, required by GCE. Changing this forces a new NAT to be created."
  default     = "cloud-nat"
}

variable "nat_ip_allocate_option" {
  description = <<EOF
    How external IPs should be allocated for this NAT. Valid values are AUTO_ONLY or MANUAL_ONLY.
    Changing this forces a new NAT to be created.
    EOF

  default = "AUTO_ONLY"
}

variable "source_subnetwork_ip_ranges_to_nat" {
  description = <<EOF
    How NAT should be configured per Subnetwork.
    Valid values include: ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS.
    Changing this forces a new NAT to be created.
    EOF

  default = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

variable "network_self_link" {
  description = "The self_link of the network to NAT."
  default     = "default"
}

variable "log_filter" {
  description = <<EOF
    Specifies the desired filtering of logs on this NAT.
    Valid values include: ALL, ERRORS_ONLY, TRANSLATIONS_ONLY
    EOF

  default = "ALL"
}

variable "log_filter_enable" {
  description = "Whether to export logs."
  default     = true
}

variable "nat_external_address_count" {
  description = "Number of static external IP addresses to create."
  default     = "1"
}
