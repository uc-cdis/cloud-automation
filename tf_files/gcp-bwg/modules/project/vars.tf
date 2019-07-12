# ---------------------------------------------------------------------------
#   REQUIRED VARIABLES
# ---------------------------------------------------------------------------
variable "organization" {
    description = "Org_Id"
}
variable "project_name" {
    description = "Name of the project."
}
variable "billing_account" {
    description = "Every working projects needs a billing account associated to it. Assign billing account."
}
variable "folder_id" {
    description = "Name of the folder to place project underneath."
}
variable "region" {
    description = "Region the project will be based out of."
}
# ---------------------------------------------------------------------------
#   DEFAULT VARIABLES
# ---------------------------------------------------------------------------
variable "set_parent_folder" {
  description = "Whether to create the project in the org root or in a folder"
  default = "true"
}

variable "enable_apis" {
  description = "Whether to actually enable the APIs. If false, this module is a no-op."
  default     = "true"
}

variable "activate_apis" {
  description = "The list of apis to activate within the project"
  type        = "list"
}

variable "disable_services_on_destroy" {
  description = "Whether project services will be disabled when the resources are destroyed. https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy"
  default     = "true"
  type        = "string"
}

# If constraints/compute.skipDefaultNetworkCreation policy is enabled, then this must be set to true
variable "auto_create_network" {
    description = "Create the 'default' network automatically."
    default = "true"
}

variable "add_csoc_service_account" {
    description = "Add the auto-created service account from the csoc to GKE viewer role."
    default = false
}

variable "csoc_project_id" {
    description = "Project ID that lives in the csoc. Must be changed if 'add_csoc_service_account' is set to true."
    default = "1234567890"
}