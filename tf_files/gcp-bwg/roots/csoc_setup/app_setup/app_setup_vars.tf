#---------------------------------------------------------------------------------------
#   Vars for General project settings
#---------------------------------------------------------------------------------------

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

#---------------------------------------------------------------------------------------
#   Vars for Compute Instance Creation
#---------------------------------------------------------------------------------------

variable "image_name" {
  description = "(Required) The name of a specific image or a family."
}

# Compute Instance Variables
variable "instance_name" {
  description = "(Required) A unique name for the resource, required by GCE. Changing this forces a new resource to be created."
}

variable "machine_type_dev" {
  description = "(Required) The machine type to create for development."
  default     = "g1-small"
}

variable "machine_type_prod" {
  description = "(Required) The machine type to create for production."
  default     = "n1-standard-1"
}

# Tags and Label Variables
/*
variable "compute_tags" {
  description = "A list of tags to attach to the instance."
  type        = "list"
}
*/
/*
variable "bastion_compute_tags" {
  description = "A list of tags to attach to the instance."
  type        = "list"
}
*/
variable "compute_labels" {
  description = "a map of key value pairs describing the system or its environment"
  type        = "map"
}

# Boot-disk Variables
variable "size" {
  description = "The size of the image in gigabytes."
  default     = "15"
}

variable "type" {
  description = "The GCE disk type."
  default     = "pd-standard"
}

variable "auto_delete" {
  description = "Whether the disk will be auto-deleted when the instance is deleted. Defaults to true"
  default     = "true"
}

# Network Interface Variables
variable "subnetwork_name" {
  description = "(Required)Name of the subnetwork in the VPC."
}

variable "ingress_subnetwork_name" {
  description = "(Required)Name of the subnetwork in the ingress VPC."
}

# Service Account block
variable "scopes" {
  type    = "list"
  default = ["userinfo-email", "compute-ro", "storage-ro", "https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/compute"]
}

# Scheduling
variable "automatic_restart" {
  description = "Specifies if the instance should be restarted if it was terminated by Compute Engine (not a user). Defaults to true."
  default     = "true"
}

variable "on_host_maintenance" {
  description = "(Optional) Describes maintenance behavior for the instance. Can be MIGRATE or TERMINATE"
  default     = "MIGRATE"
}

variable "ssh_user" {
  type        = "string"
  description = "The user we want to insert an ssh-key for"
}

variable "ssh_key_pub" {
  type        = "string"
  description = "The public key to insert for the ssh key we want to use"
}

variable "ssh_key" {
  type        = "string"
  description = "The ssh key to use"
}

#---------------------------------------------------------------------------------------
#   OPENVPN INSTANCE GROUP Variables
#---------------------------------------------------------------------------------------

variable "openvpn_name" {
  description = "Name of the instance group."
}

variable "openvpn_machine_type" {
  description = "Name of the instance group."
}

variable "openvpn_metadata_startup_script" {
  description = "Startup script"

  #default     = "../../../modules/compute-group/scripts/squid-install.sh"
}

variable "openvpn_target_size" {
  description = "The target number of instances in the group."
}

variable "openvpn_tags" {
  description = "Firewall tags to be assigned to the instances."
  default     = ["openvpn", "proxy-access"]
}

variable "openvpn_base_instance_name" {
  description = "The name of the instances created in the group."
  default     = "base-instance"
}

variable "openvpn_zone" {
  description = "The zone which further specifies the region."
  default     = "us-central1-c"
}

variable "openvpn_target_pool_name" {
  description = "Name of target-pool."
  default     = "target-pool"
}

variable "openvpn_source_image" {
  description = "The image from which to initialize this disk."
  default     = "debian-cloud/debian-9"
}

variable "openvpn_instance_template_name" {
  description = "Name of the template."
  default     = "template"
}

variable "openvpn_instance_group_manager_name" {
  description = "Name of the instance group."
  default     = "instance-group"
}

variable "openvpn_automatic_restart" {
  description = "Specifies whether the instance should be automatically restarted if it is terminated by Compute Engine (not terminated by a user). This defaults to true."
  default     = true
}

variable "openvpn_on_host_maintenance" {
  description = "Defines the maintenance behavior for this instance."
  default     = "MIGRATE"
}

variable "openvpn_labels" {
  description = "A set of key/value label pairs to assign to instances created from this template."
  type        = "map"
  default     = {}
}

variable "openvpn_access_config" {
  description = "The access config block for the instances. Set to [] to remove external IP."
  type        = "list"

  default = [
    {},
  ]
}

variable "openvpn_network_ip" {
  description = "Set the network IP of the instance in the template. Useful for instance groups of size 1."
  default     = ""
}

variable "openvpn_can_ip_forward" {
  description = "Allow ip forwarding."
  default     = false
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

  #default     = "../../../modules/compute-group/scripts/squid-install.sh"
}

variable "squid_target_size" {
  description = "The target number of instances in the group."
}

variable "squid_tags" {
  description = "Firewall tags to be assigned to the instances."
  default     = ["proxy", "web-access"]
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
#   AUTOSCALER - OPENVPN
# -------------------------------------------------------------------------------------

variable "openvpn_min_replicas" {
  description = "The minimum number of replicas that the autoscaler can scale down to."
}

variable "openvpn_max_replicas" {
  description = "The maximum number of replicas that the autoscaler can scale down to."
}

variable "openvpn_cpu_utilization_target" {
  description = "Defines the CPU utilization policy that allows the autoscaler to scale based on the average CPU utilization of a managed instance group. Must be a float value in the range (0, 1]"
}

variable "openvpn_cooldown_period" {
  description = "The number of seconds that the autoscaler should wait before it starts collecting information from a new instance."
}

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
#   FIREWALL HEALTHCHECK - OPENVPN
# -------------------------------------------------------------------------------------

variable "openvpn_enable_logging" {
  default = true
}

variable "openvpn_direction" {
  description = "Ingress or Egress"
  default     = "INGRESS"
}

variable "openvpn_priority" {
  default = "1000"
}

variable "openvpn_fw_name" {
  description = "Name of the Firewall rule"
  default     = "health-check"
}

variable "openvpn_source_ranges" {
  type        = "list"
  description = "A list of source CIDR ranges that this firewall applies to. Can't be used for EGRESS"
  default     = ["130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22"]
}

variable "openvpn_target_tags" {
  type        = "list"
  description = "A list of target tags for this firewall"
  default     = ["openvpn", "proxy-access"]
}

variable "openvpn_protocol" {
  description = "The name of the protocol to allow. This value can either be one of the following well known protocol strings (tcp, udp, icmp, esp, ah, sctp), or the IP protocol number, or all"
  default     = "TCP"
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

variable "squid_fw_target_tags" {
  type        = "list"
  description = "A list of target tags for this firewall"
  default     = ["proxy", "web-access"]
}

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

#variable "squid_lb_protocol" {
#  description = "An optional list of ports to which this rule applies.Options tcp,udp,icmp,esp,ah,sctp"
#  default     = "TCP"
#}

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

#---------------------------------------------------------------------------------------
#   Vars for Bucket Creation
#---------------------------------------------------------------------------------------
variable "bucket_data_access_logs" {
  description = "Bucket name for data access logs."
}

variable "bucket_activity_logs" {
  description = "Bucket name for admin activity logs."
}

variable "bucket_destroy" {
  description = "Destroy the bucket and all the objects."
  default     = "true"
}

variable "bucket_class" {
  description = "Bucket storage class."
  default     = "REGIONAL"
}

#---------------------------------------------------------------------------------------
#   Vars for Organization Log Sink Creation
#---------------------------------------------------------------------------------------
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
  default     = "logName:data_access"
}

variable "activity_filter" {
  description = "The filter to apply when exporting logs."
  default     = "logName:activity"
}

variable "bucket_activity_logs_labels" {
  description = "A set of key/value label pairs to assign to the bucket."
  type        = "map"
}

variable "bucket_data_access_logs_labels" {
  description = "A set of key/value label pairs to assign to the bucket."
  type        = "map"
}

# ----------------------------------------
#    OPENVPN LOAD BALANCER
# ----------------------------------------

variable "openvpn_lb_port" {
  description = "Port for the load balancer."
}
