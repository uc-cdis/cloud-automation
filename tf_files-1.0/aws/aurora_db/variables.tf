variable "vpc_name" {}

variable "service" {}

variable "admin_database_username" {
  default = "postgres"
}

variable "admin_database_name" {
  default = "postgres"
}

variable "admin_database_password" {}

variable "namespace" {
  default = "default"
}

variable "role" {}

variable "database_name" {}

variable "username" {}

variable "password" {}

variable "secrets_manager_enabled" {
  default = true
}