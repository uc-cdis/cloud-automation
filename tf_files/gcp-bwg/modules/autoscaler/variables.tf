# ---------------------------------------------------------
#   REQUIRED VARIABLES
# ---------------------------------------------------------

variable "project" {
  description = "Project this resource belongs to."
}

variable "name" {
  description = "The name of the autoscaler"
}

variable "target_instance_group" {
  description = "URL of the managed instance group that this autoscaler will scale."
}

variable "min_replicas" {
  description = "The minimum number of replicas that the autoscaler can scale down to."
}

variable "max_replicas" {
  description = "The maximum number of replicas that the autoscaler can scale down to."
}

variable "cpu_utilization_target" {
  description = "Defines the CPU utilization policy that allows the autoscaler to scale based on the average CPU utilization of a managed instance group. Must be a float value in the range (0, 1]"
}

# ---------------------------------------------------------
#   OPTIONAL DEFAULT VARIABLES
# ---------------------------------------------------------

variable "zone" {
  description = "The zone which further specifies the region."

  #default     = "us-central1-c"
}

variable "cooldown_period" {
  description = "The number of seconds that the autoscaler should wait before it starts collecting information from a new instance."
}
