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


################################
# Log Sync Variables
################################

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
  default = "logName:activity"
}
variable "activity_filter" {
  description = "The filter to apply when exporting logs."
  default = "logName:data_access"
}