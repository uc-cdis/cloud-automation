/*
variable "region" {}
variable "commons_sql_name" {}
variable "project" {}
variable "instance_region" {}
#variable "private_ip_enabled" {}
variable "network" {}
variable "zone" {}
variable "postgresql_version" {}
variable "tier" {}
variable "availability_type" {}
variable "disk_size" {}
variable "user_name" {
  description = "The name of the default user"
  default     = "default"
}
variable "user_password" {
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
  default     = ""
}

*/

variable "project_id" {
  description = "The project ID to manage the Cloud SQL resources"
}

variable "name" {
  description = "The name of the Cloud SQL resources"
}

// required
variable "database_version" {
  description = "The database version to use"
}

// required
variable "region" {
  description = "The region of the Cloud SQL resources"
}

variable "tier" {
  description = "The tier for the master instance."
}

variable "availability_type" {
  description = "The availability type for the master instance.This is only used to set up high availability for the PostgreSQL instance. Can be either `ZONAL` or `REGIONAL`."
}

variable "disk_autoresize" {
  description = "Configuration to increase storage size."
}

variable "disk_size" {
  description = "The disk size for the master instance."
}

variable "maintenance_window_day" {
  description = "The day of week (1-7) for the master instance maintenance."
}

variable "maintenance_window_hour" {
  description = "The hour of day (0-23) maintenance window for the master instance maintenance."
}

variable "maintenance_window_update_track" {
  description = "The update track of maintenance window for the master instance maintenance.Can be either `canary` or `stable`."
}

/*
variable "user_labels" {
  description = "The key/value labels for the master instances."
  
}
*/
variable "db_name" {
  description = "The name of the default database to create"
}

variable "user_name" {
  description = "The name of the default user"
}

variable "user_host" {
  description = "The host for the default user"
}

variable "user_password" {
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
}
