# Project Variables
variable "org_id" {
  description = "GCP Organization ID"
  default     = ""
}

variable "project_name" {
  description = "Name of the GCP Project"
  default = "my-first-project"
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

variable "module_source_folder" {
  default = "../../../modules/folder"
}

variable "module_source_project" {
  default = "../../../modules/project"
}
