variable "project_id" {
  description = "The project ID to manage the Cloud SQL resources"
}

variable "region" {
  description = "The region the instance will sit in."
  default     = "us-central1"
}

variable "name" {
  description = "The name of the Cloud SQL resources. If left blank GCP will randomize name."
  default     = ""
}

variable "global_address_name" {
  description = "Name of the global address resource."
  default     = "cloudsql-private-ip-address"
}

variable "global_address_purpose" {
  description = "The purpose of the resource.VPC_PEERING - for peer networks."
  default     = "VPC_PEERING"
}

variable "global_address_type" {
  description = "The type of the address to reserve. Use External or Internal. Default is Internal."
  default     = "INTERNAL"
}

variable "global_address_prefix" {
  description = "The prefix length of the IP range. Not applicable if address type=EXTERNAL."
  default     = "16"
}

variable "database_version" {
  description = "The database version to use."
  default     = "POSTGRES_9_6"
}

variable "tier" {
  description = "The tier for the master instance.Postgres supports only shared-core machine types such as db-f1-micro"
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "The availability type for the master instance.This is only used to set up high availability for the PostgreSQL instance. Can be either `ZONAL` or `REGIONAL`."
  default     = "ZONAL"
}

variable "backup_enabled" {
  description = "True if backup configuration is enabled."
  default     = "true"
}

variable "backup_start_time" {
  description = "HH:MM format time indicating when backup configuration starts."
  default     = "02:00"
}

variable "disk_autoresize" {
  description = "Configuration to increase storage size."
  default     = "true"
}

variable "disk_size" {
  description = "The disk size for the master instance."
  default     = "10"
}

variable "disk_type" {
  description = "The type of data disk: PD_SSD or PD_HDD."
  default     = "PD_SSD"
}

variable "maintenance_window_day" {
  description = "The day of week (1-7) for the master instance maintenance."
  default     = "7"
}

variable "maintenance_window_hour" {
  description = "The hour of day (0-23) maintenance window for the master instance maintenance."
  default     = "2"
}

variable "maintenance_window_update_track" {
  description = "The update track of maintenance window for the master instance maintenance.Can be either `canary` or `stable`."
  default     = "stable"
}

variable "user_labels" {
  description = "The key/value labels for the master instances."
  type        = "map"
  default     = {}
}

variable "ipv4_enabled" {
  description = "Whether this Cloud SQL instance should be assigned a public IPV4 address."
  default     = "false"
}

variable "network" {
  description = "Network name inside of the VPC."
  default     = "default"
}

variable "sql_network" {
  description = "Network name inside of the VPC."
  default     = "default"
}

/*
variable "authorized_networks" {
  description = "Allowed networks to connect to this sql instance."
  default     = []
}
*/
variable "activation_policy" {
  description = "This specifies when the instance should be active. Can be either ALWAYS, NEVER or ON_DEMAND."
  default     = "ALWAYS"
}

variable "db_name" {
  description = "The name of the default database to create"
  type        = "list"
  default     = []
}

variable "user_name" {
  description = "The name of the default user"
  default     = "postgres-user"
}

variable "user_host" {
  description = "The host for the default user.This is only supported for MySQL instances."
  default     = ""
}

variable "user_password" {
  description = "The password for the default user. If not set, a random one will be generated and available in the generated_user_password output variable."
  default     = ""
}
