variable "credential_file" {}
variable "region" {}

variable "organization" {
    description = "The name of the Organization."
    default = "prorelativity.com"
}

variable "folder_staging" {
    default = "Staging"
}

variable "folder_prod" {
  default = "Production"
}
