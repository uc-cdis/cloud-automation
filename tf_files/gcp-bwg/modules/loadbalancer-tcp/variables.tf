# ---------------------------------------------------------
#   REQUIRED VARIABLES
# ---------------------------------------------------------

variable project {
  description = "The project to deploy to, if not set the default provider project is used."
}

variable name {
  description = "Name for the forwarding rule and prefix for supporting resources."
}

variable health_port {
  description = "Port to perform health checks on."
}

# ---------------------------------------------------------
#   OPTIONAL DEFAULT VARIABLES
#   Default values are commented out to make it easier to copy into MAIN module and uncomment there
# ---------------------------------------------------------

variable region {
  description = "Region for cloud resources."
  #default     = "us-central1"
}

variable network {
  description = "Name of the network to create resources in."
  #default     = "default"
}

variable subnetwork {
  description = "Name of the subnetwork to create resources in."
  #default     = "default"
}

variable target_tags = {
  description = "List of target tags to allow traffic using firewall rule."
  type        = "list"
  #default = []
}

variable session_affinity {
  description = "How to distribute load. Options are `NONE`, `CLIENT_IP` and `CLIENT_IP_PROTO`"
  #default     = "NONE"
}

variable "load_balancing_scheme" {
  #default = "INTERNAL"
}

variable "protocol" {
  description = "An optional list of ports to which this rule applies.Options tcp,udp,icmp,esp,ah,sctp"
  #default = "TCP"
}

variable ip_address {
  description = "IP address of the internal load balancer, if empty one will be assigned. Default is empty."
  #default     = ""
}

variable ip_protocol {
  description = "The IP protocol for the backend and frontend forwarding rule. TCP or UDP."
  #default     = "TCP"
}

variable backends {
  description = "List of backends, should be a map of key-value pairs for each backend, mush have the 'group' key."
  type        = "list"
}

variable http_health_check {
  description = "Set to true if health check is type http, otherwise health check is tcp."
  #default     = false
}

variable ports {
  description = "List of ports range to forward to backend services. Max is 5."
  type        = "list"
}
