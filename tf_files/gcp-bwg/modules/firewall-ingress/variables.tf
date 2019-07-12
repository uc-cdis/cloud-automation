variable "enable_logging" {}

variable "project_id" {}

variable "direction" {
  description = "Ingress or Egress"
}

variable "priority" {}

variable "name" {
  description = "Name of the Firewall rule"
}

variable "network" {
  description = "The name or self_link of the network to attach this firewall to"
}

variable "source_ranges" {
  type        = "list"
  description = "A list of source CIDR ranges that this firewall applies to. Can't be used for EGRESS"
}

variable "target_tags" {
  type        = "list"
  description = "A list of target tags for this firewall"
}

variable "protocol" {
  description = "The name of the protocol to allow. This value can either be one of the following well known protocol strings (tcp, udp, icmp, esp, ah, sctp), or the IP protocol number, or all"
}

variable "ports" {
  type        = "list"
  description = "List of ports and/or port ranges to allow. This can only be specified if the protocol is TCP or UDP"
}
