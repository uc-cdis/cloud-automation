variable "count_compute" {
  description = "The total number of instances to create."
  default     = "1"
}

variable "count_start" {
  default = "1"
}

variable "environment" {
  description = "Select envrironment type of prod or dev to change instance types. Prod = n1-standard-1, dev = g1-small"
  default     = "dev"
}

variable "image_name" {
  description = "(Required) The name of a specific image or a family."
  default     = "ubuntu-1604-lts"
}

# Compute Instance Variables
variable "instance_name" {
  description = "(Required) A unique name for the resource, required by GCE. Changing this forces a new resource to be created."

  #default = "instance"
}

variable "machine_type_dev" {
  description = "(Required) The machine type to create for development."
  default     = "g1-small"
}

variable "machine_type_prod" {
  description = "(Required) The machine type to create for production."
  default     = "n1-standard-1"
}

variable "project" {
  description = "The ID of the project in which the resource belongs."
}

variable "region" {
  default = "us-central1"
}

variable "compute_tags" {
  description = "A list of tags to attach to the instance."
  type        = "list"
  default     = []
}
variable "compute_labels" {
  type    = "map"
  default = {}
}

# Boot-disk Variables
variable "size" {
  description = "The size of the image in gigabytes."
  default     = "15"
}

variable "type" {
  description = "The GCE disk type."
  default     = "pd-ssd"
}
variable "auto_delete" {
  description = "Whether the disk will be auto-deleted when the instance is deleted. Defaults to true"
  default     = "true"
}

# Network Interface Variables
variable "subnetwork_name" {
  type = "string"
  description = "Name of the subnetwork in the VPC."
}

# Service Account block
variable "scopes" {
  description = "(Required) A list of service scopes."
  type        = "list"
  default     = ["userinfo-email", "compute-ro", "storage-ro"]
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
  type = "string"
  description = "The user we want to insert an ssh-key for"
}

variable "ssh_key_pub" {
  type = "string"
  description = "The public key to insert for the ssh key we want to use"
}

variable "ssh_key" {
  type = "string"
  description = "The ssh key to use"
}

variable "metadata_startup_script" {
    default = ""
}