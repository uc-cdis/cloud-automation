variable "enable_logging" {
  description = " This field denotes whether to enable logging for a particular firewall rule."
  default     = "true"
}

variable "description" {
  description = "An optional description of this resource."
  default     = "Managed by Terraform."
}

variable "project_id" {
  description = " The ID of the project in which the resource belongs."
}

variable "direction" {
  description = "Ingress or Egress"
  default     = "INGRESS"
}

variable "priority" {
  description = "Priority for this rule. This is an integer between 0 and 65535."
  default     = "1000"
}

variable "name" {
  description = "Name of the Firewall rule"
}

variable "network" {
  description = "The name or self_link of the network to attach this firewall to."
  default     = "default"
}

variable "source_ranges" {
  type        = "list"
  description = "A list of source CIDR ranges that this firewall applies to. Can't be used for EGRESS"
  default     = ["0.0.0.0/0"]
}

variable "target_tags" {
  type        = "list"
  description = "A list of target tags for this firewall"
  default     = []
}

variable "protocol" {
  description = "The name of the protocol to allow. This value can either be one of the following well known protocol strings (tcp, udp, icmp, esp, ah, sctp), or the IP protocol number, or all"
}

variable "ports" {
  type        = "list"
  description = "List of ports and/or port ranges to allow. This can only be specified if the protocol is TCP or UDP"
  default     = []
}
