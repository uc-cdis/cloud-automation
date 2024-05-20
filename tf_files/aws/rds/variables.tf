variable "rds_instance_create" {
  description = "Whether to create this resource or not?"
#  type        = bool
  default     = true
}

variable "rds_instance_allocated_storage" {
  description = "The allocated storage in gibibytes"
#  type        = "number"
#  default     = 20
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

variable "rds_instance_instance_class" {
  description = "The instance type of the RDS instance"
  default     = "db.t2.micro"
}

variable "rds_instance_name" {
  description = "Name for the database to be created"
  default     = ""
}

variable "rds_instance_identifier" {
  description = "The name of the RDS instance, if omitted, Terraform will assign a random, unique identifier"
  type        = "string"
}

variable "rds_instance_username" {
  description = "Username to use"
#  default     = ""
}

variable "rds_instance_password" {
  description = "Password to use"
  default     = ""
}

variable "rds_instance_parameter_group_name" {
  description = "Name of the DB parameter group to associate"
  default     = ""
}

variable "rds_instance_allow_major_version_upgrade" {
  description = "Indicates that major version upgrades are allowed"
#  type        = "bool"
  default     = true
}

variable "rds_instance_apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately, or during the next maintenance window"
#  type        = "bool"
  default     = false
}

variable "rds_instance_auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window"
#  type        = "bool"
  default     = true
}

variable "rds_instance_backup_retention_period" {
  description = "The days to retain backups for. Must be between 0 and 35"
#  type        = "number"
  default     = 0
}

variable "rds_instance_backup_window" {
  description = "The daily time range (in UTC) during which automated backups are created if they are enabled. Example: '09:46-10:16'. Must not overlap with maintenance_window"
  default     = "03:46-04:16"
}

variable "rds_instance_db_subnet_group_name" {
  description = "Name of DB subnet group. DB instance will be created in the VPC associated with the DB subnet group"
  type        = "string"
#  default     = ""
}

variable "rds_instance_maintenance_window" {
  description = "The window to perform maintenance in"
  type        = "string"
  default     = "Mon:00:00-Mon:03:00"
}

variable "rds_instance_multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
#  type        = "bool"
  default     = false
}

variable "rds_instance_option_group_name" {
  description = "Name of the DB option group to associate"
  type        = "string" 
  default     = ""
}

variable "rds_instance_publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
#  type        = "bool"
  default     = false
}

variable "rds_instance_skip_final_snapshot" {
  description = "rds_instance_skip_final_snapshot"
#  type        = "bool"
  default     = false
}

variable "rds_instance_storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
#  type        = "bool"
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
  type        = "string"
#  default     = ""
}

variable "rds_instance_license_model" {
  description = "License model information for this DB instance"
  type        = "string"
  default     = ""
}

variable "rds_instance_performance_insights_enabled" {
  description = "Specifies whether Performance Insights are enabled"
#  type        = "bool"
  default     = false
}

variable "rds_instance_performance_insights_retention_period" {
  description = "The amount of time in days to retain Performance Insights data. Either 7 (7 days) or 731 (2 years)."
#  type        = "number"
  default     = 7
}

variable "rds_instance_timeouts" {
  description = "(Optional) Updated Terraform resource management timeouts. Applies to `aws_db_instance` in particular to permit resource management times"
  type        = "map"
  default = {
    create = "40m"
    update = "80m"
    delete = "40m"
  }
}

variable "rds_instance_monitoring_role_name" {
  description = "Name of the IAM role which will be created when create_monitoring_role is enabled."
#  type        = "string"
  default     = "rds-monitoring-role"
}

variable "rds_instance_max_allocated_storage" {
  description = "Specifies the value for Storage Autoscaling"
#  type        = "number"
  default     = 0
}

variable "rds_instance_availability_zone" {
  description = "The Availability Zone of the RDS instance"
#  type        = "string"
  default     = ""
}

variable "rds_instance_final_snapshot_identifier" {
  description = "The name of your final DB snapshot when this DB instance is deleted."
#  type        = "string"
  default     = false #null
}

variable "rds_instance_monitoring_role_arn" {
  description = "The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. Must be specified if monitoring_interval is non-zero."
#  type        = "string"ß
  default     = ""
}

variable "rds_instance_copy_tags_to_snapshot" {
  description = "On delete, copy all Instance tags to the final snapshot (if final_snapshot_identifier is specified)"
#  type        = bool
  default     = false
}

variable "rds_instance_kms_key_id" {
  description = "The ARN for the KMS encryption key. If creating an encrypted replica, set this to the destination KMS ARN. If storage_encrypted is set to true and kms_key_id is not specified the default KMS key created in your account will be used"
#  type        = "string"
  default     = ""
}

variable "rds_instance_enabled_cloudwatch_logs_exports" {
  description = "List of log types to enable for exporting to CloudWatch logs. If omitted, no logs will be exported. Valid values (depending on engine): alert, audit, error, general, listener, slowquery, trace, postgresql (PostgreSQL), upgrade (PostgreSQL)."
  type        = "list"
  default     = []
}

variable "rds_instance_iops" {
  description = "The amount of provisioned IOPS. Setting this implies a storage_type of 'io1'"
#  type        = number
  default     = 0
}

variable "rds_instance_deletion_protection" {
  description = "The database can't be deleted when this value is set to true."
#  type        = bool
  default     = false
}

variable "rds_instance_iam_database_authentication_enabled" {
  description = "Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled"
#  type        = bool
  default     = false
}

variable "rds_instance_timezone" {
  description = "(Optional) Time zone of the DB instance. timezone is currently only supported by Microsoft SQL Server. The timezone can only be set on creation. See MSSQL User Guide for more information."
  type        = "string"
  default     = ""
}

variable "rds_instance_monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. To disable collecting Enhanced Monitoring metrics, specify 0. The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60."
#  type        = number
  default     = 0
}

variable "rds_instance_snapshot_identifier" {
  description = "Specifies whether or not to create this database from a snapshot. This correlates to the snapshot ID you'd find in the RDS console, e.g: rds:production-2015-06-26-06-05."
  type        = "string"
  default     = ""
}

variable "rds_instance_replicate_source_db" {
  description = "Specifies that this resource is a Replicate database, and to use this value as the source database. This correlates to the identifier of another Amazon RDS Database to replicate."
  type        = "string"
  default     = ""
}

variable "rds_instance_create_monitoring_role" {
  description = "Create IAM role with a defined name that permits RDS to send enhanced monitoring metrics to CloudWatch Logs."
#  type        = bool
  default     = false
}

variable "rds_instance_character_set_name" {
  description = "(Optional) The character set name to use for DB encoding in Oracle instances. This can't be changed. See Oracle Character Sets Supported in Amazon RDS for more information"
  type        = "string"
  default     = ""
}

variable "rds_instance_backup_enabled" {
  description = "To enable backups onto S3"
  default    = false
}

variable "rds_instance_backup_kms_key" {
  description = "KMS to enable backups onto S3"
  default     = ""
}

variable "rds_instance_backup_bucket_name" {
  description = "The bucket to send bacups to"
  default     = ""
}
