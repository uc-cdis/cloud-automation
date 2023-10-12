variable "vpc_name" {
  default = ""
}

variable "service" {
  default = ""
}

variable "admin_database_username" {
  default = "postgres"
}

variable "admin_database_name" {
  default = "postgres"
}

variable "admin_database_password" {
  default = ""
}

variable "namespace" {
  default = "default"
}

variable "role" {
  default = ""
}

variable "database_name" {
  default = ""
}

variable "username" {
  default = ""
}

variable "password" {
  default = ""
}

variable "secrets_manager_enabled" {
  default = true
}

variable "dump_file_to_restore" {
  default = ""
}

variable "dump_file_storage_location" {
  default = ""
}

variable "db_restore" {
  default = false
}

variable "db_dump" {
  default = false
}

variable "db_job_role_arn" {
  default = ""
}