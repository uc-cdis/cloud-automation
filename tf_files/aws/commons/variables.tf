variable "vpc_name" {
  default = "Commons1"
}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_cert_name" {
  default = "AWS-CERTIFICATE-NAME"
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

variable "indexd_prefix" {
  default = "dg.XXXX/"
}

variable "db_password_peregrine" {}

variable "db_password_sheepdog" {}

variable "db_password_indexd" {}

variable "dictionary_url" {
  # ex: dev dictionary is at: https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json
}

variable "portal_app" {
  # passed through to portal's APP environment to customize for environment
  default = "dev"
}

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
  default = "db.t2.micro"
}

variable "sheepdog_db_instance" {
  default = "db.t2.micro"
}

variable "indexd_db_instance" {
  default = "db.t2.micro"
}

variable "hostname" {
  default = "dev.bionimbus.org"
}

variable "kube_ssh_key" {}

/* A list of ssh keys that will be added to
   kubernete nodes, Example:
   '- ssh-rsa XXXX\n - ssh-rsa XXX' */
variable "kube_additional_keys" {
  default = ""
}

variable "google_client_id" {}

variable "google_client_secret" {}

# 32 alphanumeric characters
variable "hmac_encryption_key" {}

variable "gdcapi_secret_key" {}

# password for write access to indexd
variable "gdcapi_indexd_password" {}

#
# DEPRECATED - should no longer be necessary
# gdcapi's oauth2 client id (fence as oauth2 provider)
#
variable "gdcapi_oauth2_client_id" {
  default = ""
}

#
# DEPRECATED - should no longer be necessary
# gdcapi's oauth2 client id (fence as oauth2 provider)
#
variable "gdcapi_oauth2_client_secret" {
  default = ""
}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "707767160287"
}

variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "squid-nlb-endpointservice-name" {
  default = "com.amazonaws.vpce.us-east-1.vpce-svc-0ce2261f708539011"
  }

# Path to user.yaml in s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml
variable "config_folder" {}

locals {
  # kube-aws does not like '-' in cluster name
  cluster_name = "${replace(var.vpc_name, "-", "")}"
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
  default = "yes"
}

variable "organization_name" {
  default = "Basic Service"
}


## Mailgun variable defaults/definitions.
variable "mailgun_api_key" {
  default = ""
}

variable "mailgun_smtp_host" {
  default = "smtp.mailgun.org"
}

variable "mailgun_api_url" {
  default = "https://api.mailgun.net/v3/"
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
  default = "9.6.11" 
}

variable "sheepdog_engine_version" {
  default = "9.6.11"
}

variable "indexd_engine_version" {
  default = "9.6.11" 
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

variable "users_bucket_name" {
  default = "cdis-gen3-users"
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

variable "squid_instance_type" {
  description = "Instance type for HA squid"
  default     = "t3.medium"
}

variable "squid_instance_drive_size" {
  description = "Volume size for HA squid instances"
  default     = 8
}
