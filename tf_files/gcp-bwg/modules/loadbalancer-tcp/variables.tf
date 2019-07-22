variable project {
  description = "The project to deploy to, if not set the default provider project is used."
}

variable region {
  description = "Region for cloud resources."
  default     = "us-central1"
}

variable network {
  description = "Name of the network to create resources in."
  default     = "default"
}

variable firewall_project {
  description = "Name of the project to create the firewall rule in. Useful for shared VPC. Default is var.project."
  default     = ""
}

variable name {
  description = "Name for the forwarding rule and prefix for supporting resources."
}

variable service_port {
  description = "TCP port your service is listening on."
}

variable target_tags {
  description = "List of target tags to allow traffic using firewall rule."
  type        = "list"
  default = []
}

variable session_affinity {
  description = "How to distribute load. Options are `NONE`, `CLIENT_IP` and `CLIENT_IP_PROTO`"
  default     = "NONE"
}
variable "load_balancing_scheme" {
  default = "EXTERNAL"
}

variable "protocol" {
  description = "An optional list of ports to which this rule applies.Options tcp,udp,icmp,esp,ah,sctp"
  default = "tcp"
}

variable "source_ranges" {
  description = " If source ranges are specified, the firewall will apply only to traffic that has source IP address in these ranges. These ranges must be expressed in CIDR format"
  type = "list"
  default = []
}


