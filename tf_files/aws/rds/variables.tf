
variable "rds_instance_allocated_storage" {
  description = "The allocated storage in gibibytes"
  type        = number
  default     = 20
}

variable "rds_instance_storage_type" {
  description = "gp2, io1, standard"
  default     = "gp2"
}

variable "rds_instance_engine" {
  description = "The database engine to use"
#  default     = ""
}

variable "rds_instance_engine_version" {
  description = "The engine version to use. If auto_minor_version_upgrade is enabled, you can provide a prefix of the version such as 5.7 (for 5.7.10) and this attribute will ignore differences in the patch version automatically (e.g. 5.7.17)"
#  default     = ""
}

variable "rds_instance_class" {
  description = "The instance type of the RDS instance"
  default     = "db.t2.micro"
}

variable "rds_instance_name" {
  description = "Name for the database to be created"
#  default     = ""
}

variable "rds_instance_username" {
  description = "Username to use"
#  default     = ""
}

variable "rds_instance_password" {
  description = "Password to use"
#  default     = ""
}

variable "rds_instance_parameter_group_name" {
  description = "Name of the DB parameter group to associate"
  default     = ""
}

variable "rds_instance_allow_major_version_update" {
  description = "Indicates that major version upgrades are allowed"
  type        = bool
  default     = true
}

variable "rds_instance_apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately, or during the next maintenance window"
  type        = bool
  default     = false
}

variable "rds_instance_auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window"
  type        = bool
  default     = true
}

variable "rds_instance_az" {
  description = "The AZ for the RDS instance"
  type        = string
  default     = ""
}

variable "rds_instance_backup_retention_period" {
  description = "The days to retain backups for. Must be between 0 and 35"
  type        = number
  default     = 0
}

variable "rds_instance_backup_window" {
  description = "The daily time range (in UTC) during which automated backups are created if they are enabled. Example: '09:46-10:16'. Must not overlap with maintenance_window"
  default     = "03:46-04:16"
}

variable "rds_instance_db_subnet_group_name" {
  description = "Name of DB subnet group. DB instance will be created in the VPC associated with the DB subnet group"
  type        = string
#  default     = ""
}

variable "rds_instance_maintenance_window" {
  description = "The window to perform maintenance in"
  type        = string
  default     = "Mon:00:00-Mon:03:00"
}

variable "rds_instance_multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

variable "rds_instance_option_group_name" {
  description = "Name of the DB option group to associate"
  type        = string 
  default     = null
}

variable "rds_instance_publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
  type        = bool
  default     = false
}

variable "rds_instance_skip_final_snapshot" {
  description = "rds_instance_skip_final_snapshot"
  type        = bool
  default     = false
}

variable "rds_instance_storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = false
}

variable "rds_instance_vpc_security_group_ids" {
  description = "List of VPC security groups to associate"
  type        = "list"
  default     = []
}

variable "rds_instance_tags" {
  description = "Tags for the instance"
  type        = "map"
  default     = {}
}

variable "rds_instance_port" {
  description = "The port on which the DB accepts connections"
  type        = string
#  default     = ""
}

variable "rds_instance_license_model" {
  description = "License model information for this DB instance"
  type        = string
  default     = ""
}

variable "rds_instance_performance_insights_enabled" {
  description = "Specifies whether Performance Insights are enabled"
  type        = bool
  default     = false
}

variable "rds_instance_performance_insights_retention_period" {
  description = "The amount of time in days to retain Performance Insights data. Either 7 (7 days) or 731 (2 years)."
  type        = number
  default     = 7
}