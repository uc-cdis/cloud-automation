# ---------------------------------------------------------
#   REQUIRED VARIABLES
# ---------------------------------------------------------

variable "project" {
  description = "The ID of the project in which the resource belongs."
}

variable "name" {
  description = "The name of the instances. If you leave this blank, Terraform will auto-generate a unique name."
}

variable "network_interface" {
  description = "Networks to attach to instances created from this template."
}

variable "subnetwork" {
  description = "The name of the subnetwork to attach this interface to. The subnetwork must exist in the same region this instance will be created in. Either network or subnetwork must be provided."
}

variable "metadata_startup_script" {
  description = "Location of metadata startup script"
}

# ---------------------------------------------------------
#   OPTIONAL DEFAULT VARIABLES
# ---------------------------------------------------------

variable "machine_type" {
  description = "(Required) The machine type to create for development."

  #default     = "f1-micro"
}

variable "base_instance_name" {
  description = "(Required) The name of the instances created in the group."

  #default     = "base-instance"
}

variable "zone" {
  description = "The zone which further specifies the region."

  #default     = "us-central1-c"
}

variable "region" {
  description = "Region the projects lives in."

  #default = "us-central1"
}

variable "target_size" {
  description = "The target number of instances in the group."

  #default     = "1"
}

variable "target_pool_name" {
  description = "Name of target-pool."

  #default     = "target-pool"
}

variable "tags" {
  description = "Tags to attach to the instance."
  type        = "list"

  #default     = []
}

variable "source_image" {
  description = "The image from which to initialize this disk."

  #default = "debian-cloud/debian-9"
}

variable "instance_template_name" {
  description = "Name of the template."

  #default = "template"
}

variable "instance_group_manager_name" {
  description = "Name of the instance group."

  #default = "instance-group"
}

variable "automatic_restart" {
  description = "Specifies whether the instance should be automatically restarted if it is terminated by Compute Engine (not terminated by a user). This defaults to true."

  # default = true
}

variable "on_host_maintenance" {
  description = "Defines the maintenance behavior for this instance."

  #default = "MIGRATE"
}

variable "labels" {
  description = "A set of key/value label pairs to assign to instances created from this template."
  type        = "map"

  #default = {}
}

variable access_config {
  description = "The access config block for the instances. Set to [] to remove external IP."
  type        = "list"

  # default = [
  #   {},
  # ]
}

variable network_ip {
  description = "Set the network IP of the instance in the template. Useful for instance groups of size 1."

  # default     = ""
}

variable can_ip_forward {
  description = "Allow ip forwarding."

  #default     = false
}
