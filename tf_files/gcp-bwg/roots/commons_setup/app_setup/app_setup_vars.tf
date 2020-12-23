########################################################################################
#   Vars for General project settings
########################################################################################

variable "project_name" {
  description = "The ID of the project in which the resource belongs."
}

variable "env" {
  description = "Development Environment suffix for project name."
}

variable "region" {
  description = "The region the project resides."
  default     = "us-central1"
}

variable "credential_file" {
  description = "The service account key json file being used to create this project."
  default     = "../credentials.json"
}

variable "state_bucket_name" {
  description = "The cloud storage bucket being used to store the resulting remote state files"
  default     = "my-tf-state"
}

variable "terraform_workspace" {
  description = "The filename being used for the remote state storage on GCP Cloud Storage Buckets"
  default     = "my-workspace"
}

variable "prefix_org_setup" {
  description = "The prefix being used by the org_setup section of the terraform project to create the directory in cloud storage for remote state"
}

variable "prefix_project_setup" {
  description = "The prefix being used by the project_setup section of the terraform project to create the directory in cloud storage for remote state"
}

variable "prefix_app_setup" {
  description = "The prefix being used by the app_setup section of the terraform project to create the directory in the cloud storage for remote state"
}

variable "prefix_app_setup_csoc" {
  description = "The prefix used by the app_setup_csoc section of the terraofrm project in the CSOC project located in the cloud storage."
}

variable "tf_state_app_setup_csoc" {
  description = "The filename being used for the remote state storage of the app_setup in the CSOC project."
}

variable "state_bucket_name_csoc" {
  description = "GCP Cloud Storage bucket name where CSOC terraform state lives."
}

variable "count_compute" {
  description = "The total number of instances to create."
  default     = "1"
}

variable "count_start" {
  default = "1"
}

variable "environment" {
  description = "(Required)Select envrironment type of prod or dev to change instance types. Prod = n1-standard-1, dev = g1-small"
  default     = "dev"
}

# -------------------------------------------------------
#  Log Sync Variables
# -------------------------------------------------------

variable "org_id" {
  description = "The numeric ID of the organization to be exported to the sink."
}

variable "data_access_sink_name" {
  description = "The name of the logging sink."
}

variable "activity_sink_name" {
  description = "The name of the logging sink."
}

variable "data_access_filter" {
  description = "The filter to apply when exporting logs."
  default     = "logName:activity"
}

variable "activity_filter" {
  description = "The filter to apply when exporting logs."
  default     = "logName:data_access"
}

#---------------------------------------------------------------------------------------
#   SQUID INSTANCE GROUP Variables
#---------------------------------------------------------------------------------------

variable "squid_name" {
  description = "Name of the instance group."
}

variable "squid_machine_type" {
  description = "Name of the instance group."
}

variable "squid_metadata_startup_script" {
  description = "Startup script"
}

variable "squid_target_size" {
  description = "The target number of instances in the group."
}

variable "squid_base_instance_name" {
  description = "The name of the instances created in the group."
  default     = "base-instance"
}

variable "squid_zone" {
  description = "The zone which further specifies the region."
  default     = "us-central1-c"
}

variable "squid_target_pool_name" {
  description = "Name of target-pool."
  default     = "target-pool"
}

variable "squid_source_image" {
  description = "The image from which to initialize this disk."
  default     = "debian-cloud/debian-9"
}

variable "squid_instance_template_name" {
  description = "Name of the template."
  default     = "template"
}

variable "squid_instance_group_manager_name" {
  description = "Name of the instance group."
  default     = "instance-group"
}

variable "squid_automatic_restart" {
  description = "Specifies whether the instance should be automatically restarted if it is terminated by Compute Engine (not terminated by a user). This defaults to true."
  default     = true
}

variable "squid_on_host_maintenance" {
  description = "Defines the maintenance behavior for this instance."
  default     = "MIGRATE"
}

variable "squid_labels" {
  description = "A set of key/value label pairs to assign to instances created from this template."
  type        = "map"
  default     = {}
}

variable "squid_access_config" {
  description = "The access config block for the instances. Set to [] to remove external IP."
  type        = "list"

  default = [
    {},
  ]
}

variable "squid_network_ip" {
  description = "Set the network IP of the instance in the template. Useful for instance groups of size 1."
  default     = ""
}

variable "squid_can_ip_forward" {
  description = "Allow ip forwarding."
  default     = false
}

variable "squid_hc_name" {
  description = "Name of the health check resource."
  default     = "health-check"
}

variable "squid_hc_check_interval_sec" {
  description = "How often (in seconds) to send a health check. The default value is 5 seconds."
}

variable "squid_hc_timeout_sec" {
  description = "How long (in seconds) to wait before claiming failure. The default value is 5 seconds."
}

variable "squid_hc_healthy_threshold" {
  description = "A so-far unhealthy instance will be marked healthy after this many consecutive successes. The default value is 2."
}

variable "squid_hc_unhealthy_threshold" {
  description = "A so-far healthy instance will be marked unhealthy after this many consecutive failures. The default value is 10."
}

variable "squid_hc_tcp_health_check_port" {
  description = "The TCP port number for the TCP health check request. The default value is 443."
}

# -------------------------------------------------------------------------------------
#   SQUID TAGS
# -------------------------------------------------------------------------------------

variable "egress_allow_proxy_mig_name" {}
variable "inbound_proxy_port_name" {}

#---------------------------------------------------------------------------------------
#   AUTOSCALER - SQUID
#---------------------------------------------------------------------------------------

variable "squid_min_replicas" {
  description = "The minimum number of replicas that the autoscaler can scale down to."
}

variable "squid_max_replicas" {
  description = "The maximum number of replicas that the autoscaler can scale down to."
}

variable "squid_cpu_utilization_target" {
  description = "Defines the CPU utilization policy that allows the autoscaler to scale based on the average CPU utilization of a managed instance group. Must be a float value in the range (0, 1]"
}

variable "squid_cooldown_period" {
  description = "The number of seconds that the autoscaler should wait before it starts collecting information from a new instance."
}

# -------------------------------------------------------------------------------------
#   FIREWALL HEALTHCHECK - SQUID
# -------------------------------------------------------------------------------------

variable "squid_fw_enable_logging" {
  default = true
}

variable "squid_fw_direction" {
  description = "Ingress or Egress"
  default     = "INGRESS"
}

variable "squid_fw_priority" {
  default = "1000"
}

variable "squid_fw_name" {
  description = "Name of the Firewall rule"
  default     = "health-check"
}

variable "squid_fw_source_ranges" {
  type        = "list"
  description = "A list of source CIDR ranges that this firewall applies to. Can't be used for EGRESS"
  default     = ["130.211.0.0/22", "35.191.0.0/16"]
}

/*
variable "squid_fw_target_tags" {
  type        = "list"
  description = "A list of target tags for this firewall"
  default     = ["proxy", "web-access"]
}
*/
variable "squid_fw_protocol" {
  description = "The name of the protocol to allow. This value can either be one of the following well known protocol strings (tcp, udp, icmp, esp, ah, sctp), or the IP protocol number, or all"
  default     = "TCP"
}

#---------------------------------------------------------------------------------------
#   INTERNAL LOAD BALANCER
#---------------------------------------------------------------------------------------

variable "squid_lb_name" {
  description = "Name for the forwarding rule and prefix for supporting resources."
}

/*
variable "squid_lb_health_port" {
  description = "Port to perform health checks on."
}
variable "squid_lb_ports" {
  description = "List of ports range to forward to backend services. Max is 5."
  type        = "list"
}
variable "squid_lb_target_tags" {
  description = "List of target tags to allow traffic using firewall rule."
  type        = "list"
}
*/
variable "squid_lb_session_affinity" {
  description = "How to distribute load. Options are `NONE`, `CLIENT_IP` and `CLIENT_IP_PROTO`"
  default     = "NONE"
}

variable "squid_lb_load_balancing_scheme" {
  default = "INTERNAL"
}

variable "squid_lb_ip_address" {
  description = "IP address of the internal load balancer, if empty one will be assigned. Default is empty."
  default     = ""
}

variable "squid_lb_ip_protocol" {
  description = "The IP protocol for the backend and frontend forwarding rule. TCP or UDP."
  default     = "TCP"
}

variable "squid_lb_http_health_check" {
  description = "Set to true if health check is type http, otherwise health check is tcp."
  default     = false
}
