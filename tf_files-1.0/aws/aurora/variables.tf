variable "vpc_name" {}

variable "cluster_identifier" {
  description = "Cluster Identifier"
  type        = string
  default     = "aurora-cluster"
}

variable "cluster_instance_identifier" {
  description = "Cluster Instance Identifier"
  type        = string
  default     = "aurora-cluster-instance"
}

variable "cluster_instance_class" {
  description = "Cluster Instance Class"
  type        = string
  default     = "db.serverless"
}

variable "cluster_engine" {
  description = "Aurora database engine type"
  type        = string
  default     = "aurora-postgresql"
}

variable "cluster_engine_version" {
  description = "Aurora database engine version."
  type        = string
  default     = "13.7"
}

variable "master_username" {
  description = "Master DB username"
  type        = string
  default     = "postgres"
}

variable "storage_encrypted" {
  description = "Specifies whether storage encryption is enabled"
  type        = bool
  default     = true
}

variable "apply_immediate" {
  description = "Instruct the service to apply the change immediately. This can result in a brief downtime as the server reboots. See the AWS Docs on RDS Maintenance for more information"
  type        = bool
  default     = true
}


variable "engine_mode" {
  type        = string
  description = "use provisioned for Serverless v2 RDS cluster"
  default     = "provisioned"
}


variable "serverlessv2_scaling_min_capacity" {
  type        = string
  description = "Serverless v2 RDS cluster minimum scaling capacity in ACUs"
  default     = "0.5"
}

variable "serverlessv2_scaling_max_capacity" {
  type        = string
  description = "Serverless v2 RDS cluster maximum scaling capacity in ACUs"
  default     = "10.0"
}


variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB cluster is deleted"
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  type        = string
  description = "The name of your final DB snapshot when this DB cluster is deleted"
  default     = "aurora-cluster-snapshot-final"
}


variable "backup_retention_period" {
  type        = number
  description = "The days to retain backups for"
  default     = 10
}


variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created if automated backups are enabled using the BackupRetentionPeriod parameter"
  type        = string
  default     = "02:00-03:00"
}

variable "password_length" {
  type        = number
  description = "The length of the password string"
  default     = 12
}

variable "deploy_aurora" {
  default = true
}
