variable "project_name" {
  description = "The display name of the project."
}
variable "org_id" {
  description = "The numeric ID of the organization this project belongs to."
  default = ""
}
variable "folder_id" {
  description = "The numeric ID of the folder this project should be created under. "
  default = ""
}

variable "billing_account" {
  description = "The alphanumeric ID of the billing account this project belongs to."
  default = ""
}
variable "credential_file" {
  description = "Name of the .json file"
  default = ""
}
variable "region" {
  description = "Region location"
  #default = "us-central1"
}
