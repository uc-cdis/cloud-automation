# Project Variables
variable "org_id" {
  description = "GCP Organization ID"
  default     = ""
}

variable "env" {
  description = "Environment variable."
}

variable "project_name" {
  description = "Name of the GCP Project"
  default     = "my-first-project"
}

variable "billing_account" {
  default = ""
}

variable "credential_file" {
  default = "credentials.json"
}

variable "terraform_workspace" {
  default = "my-workspace"
}

variable "prefix_org_setup" {
  default = "org_setup"
}

variable "prefix_project_setup" {
  default = "project_setup"
}

variable "state_bucket_name_csoc" {
  description = "Terraform state bucketname in the CSOC."
}

variable "prefix_org_setup_csoc" {
  description = "Terraform state folder name in the CSOC."
}

variable "tf_state_org_setup_csoc" {
  description = "Terraform state file name in the CSOC for Organization."
}

variable "region" {
  default = "us-central1"
}

variable "organization" {
  description = "The name of the Organization."
  default     = ""
}

variable "create_folder" {
  #  default = true
}

variable "set_parent_folder" {
  #  default = true
}

variable "folder" {
  default = "Production"
}

variable "prefix" {
  default = "org_setup"
}

variable "state_bucket_name" {
  default = "tf-state"
}

variable "folder_iam_binding" {
  description = "Folder Identity to apply permissions too."
  type        = "list"
  default     = []
}

// Folder Level Roles
variable "kubernetes_cluster_viewer_folder_binding" {
  description = "Read-only access to Kubernetes Clusters. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "kubernetes_engine_viewer_folder_binding" {
  description = "Provides read-only access to GKE resources. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "stackdriver_monitoring_viewer_folder_binding" {
  description = "Provides read-only access to get and list information about all monitoring data and configurations at the folder level."
  type        = "list"
  default     = []
}

variable "log_viewer_folder_binding" {
  description = "Provides access to view logs. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "compute_instance_viewer_folder_binding" {
  description = "Read-only access to get and list Compute Engine resources, without being able to read the data stored on them. Role applied at folder level."
  type        = "list"
  default     = []
}

variable "service_account_creator_folder_level" {
  description = "Create and manage service accounts at folder level."
  type        = "list"
  default     = []
}

// Cloud Storage Roles
variable "cloud_storage_viewer" {
  description = "View objects in a bucket."
  type        = "list"
  default     = []
}

variable "bucket_name_iam" {
  description = "The name of the bucket(s) it applies to."
  default     = []
}
