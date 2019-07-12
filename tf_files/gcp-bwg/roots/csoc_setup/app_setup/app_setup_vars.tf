########################################################################################
#   Vars for General project settings
########################################################################################

variable "project_name" {
  description = "The ID of the project in which the resource belongs."
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
  default = "my-tf-state"
}

variable "terraform_workspace" {
  description = "The filename being used for the remote state storage on GCP Cloud Storage Buckets"
  default = "my-workspace"
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

########################################################################################
#   Vars for Compute Instance Creation
########################################################################################

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

variable "compute_tags" {
  description = "A list of tags to attach to the instance."
  type        = "list"
}

variable "bastion_compute_tags" {
  description = "A list of tags to attach to the instance."
  type        = "list"
}

variable "compute_labels" {
  description = "a map of key value pairs describing the system or its environment"
  type = "map"
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
  type        = "list"
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

