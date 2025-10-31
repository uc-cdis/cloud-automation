variable "vpc_name" {
  default = "vpcName"
}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "fence_db_size" {
  default = 10
}

variable "sheepdog_db_size" {
  default = 10
}

variable "indexd_db_size" {
  default = 10
}

variable "db_password_fence" {}

variable "db_password_gdcapi" {
  # gdcapi now deprecated in favor of sheepdog + peregrine
  default = ""
}

variable "db_password_peregrine" {}

variable "db_password_sheepdog" {}

variable "db_password_indexd" {}

variable "fence_snapshot" {
  default = ""
}

variable "gdcapi_snapshot" {
  default = ""
}

variable "peregrine_snapshot" {
  default = ""
}

variable "sheepdog_snapshot" {
  default = ""
}

variable "indexd_snapshot" {
  default = ""
}

variable "fence_db_instance" {
  default = "db.t3.small"
}

variable "sheepdog_db_instance" {
  default = "db.t3.small"
}

variable "indexd_db_instance" {
  default = "db.t3.small"
}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "707767160287"
}

variable "peering_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "slack_webhook" {
  default = ""
}

variable "secondary_slack_webhook" {
  default = ""
}

variable "alarm_threshold" {
  default = "85"
}


variable "csoc_managed" {
  default = true
}

variable "organization_name" {
  default = "Basic Service"
}

variable "fence_ha" {
  default = false
}

variable "sheepdog_ha" {
  default = false
}

variable "indexd_ha" {
  default = false
}

variable "fence_maintenance_window"{
  default = "SAT:09:00-SAT:09:59"
}

variable "rds_instance_storage_encrypted"{
  default = true
}

variable "sheepdog_maintenance_window"{
  default = "SAT:10:00-SAT:10:59"
}

variable "indexd_maintenance_window"{
  default = "SAT:11:00-SAT:11:59"
}

variable "fence_backup_retention_period" {
  default = "4"
}

variable "sheepdog_backup_retention_period" {
  default = "4"
}

variable "indexd_backup_retention_period" {
  default = "4"
}

variable "fence_backup_window" {
  default = "06:00-06:59"
}

variable "sheepdog_backup_window" {
  default = "07:00-07:59"
}

variable "indexd_backup_window" {
  default = "08:00-08:59"
}

variable "fence_engine_version" {
  default = "13.3"
}

variable "sheepdog_engine_version" {
  default = "13.3"
}

variable "indexd_engine_version" {
  default = "13.3"
}

variable "fence_auto_minor_version_upgrade" {
  default = "true"
}

variable "indexd_auto_minor_version_upgrade" {
  default = "true"
}

variable "sheepdog_auto_minor_version_upgrade" {
  default = "true"
}

variable "fence_database_name" {
  default = "fence"
}

variable "sheepdog_database_name" {
  default = "gdcapi"
}

variable "indexd_database_name" {
  default = "indexd"
}

variable "fence_db_username" {
  default = "fence_user"
}

variable "sheepdog_db_username" {
  default = "sheepdog"
}

variable "indexd_db_username" {
  default = "indexd_user"
}

variable "fence_allow_major_version_upgrade" {
  default = "true"
}

variable "sheepdog_allow_major_version_upgrade" {
  default = "true"
}

variable "indexd_allow_major_version_upgrade" {
  default = "true"
}

variable "deploy_sheepdog_db" {
  description = "Whether or not to deploy the database instance"
  default     = true
}

variable "deploy_fence_db" {
  description = "Whether or not to deploy the database instance"
  default     = true
}

variable "deploy_indexd_db" {
  description = "Whether or not to deploy the database instance"
  default     = true
}

variable "sheepdog_engine" {
  description = "Engine to deploy the db instance"
  default     = "postgres"
}

variable "fence_engine" {
  description = "Engine to deploy the db instance"
  default     = "postgres"
}

variable "indexd_engine" {
  description = "Engine to deploy the db instance"
  default     = "postgres"
}

variable "security_group_local_id" {
  default = "securityGroupId"
}

variable "aws_db_subnet_group_name" {
  default = "subnetName"
}

variable "fence_max_allocated_storage" {
  description = "Maximum allocated storage for autosacaling"
  default     = 0
}

variable "sheepdog_max_allocated_storage" {
  description = "Maximum allocated storage for autosacaling"
  default     = 0
}

variable "indexd_max_allocated_storage" {
  description = "Maximum allocated storage for autosacaling"
  default     = 0
}
