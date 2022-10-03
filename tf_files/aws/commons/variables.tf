variable "vpc_name" {
  default = "Commons1"
}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
}

variable "secondary_cidr_block" {
  default = ""
}
  
variable "vpc_flow_logs" {
  default = false
}

variable "vpc_flow_traffic" {
  default = "ALL"
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
  default = "db.t3.small"
}

variable "sheepdog_db_instance" {
  default = "db.t3.small"
}

variable "indexd_db_instance" {
  default = "db.t3.small"
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
  default = "099720109477"
}

variable "squid_image_search_criteria" {
  description = "Search criteria for squid AMI look up"
  default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
}

variable "peering_vpc_id" {
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
  default = true
}

# controls whether or not to setup the cloudwatch subscription filter to send logs to CSOC for long term storage
# CTDS uses datadog and this is no longer needed for us.
variable "send_logs_to_csoc" {
  default = true
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

variable "ha-squid_instance_type" {
  description = "Instance type for HA squid"
  default     = "t3.medium"
}

variable "ha-squid_instance_drive_size" {
  description = "Volume size for HA squid instances"
  default     = 8
}


variable "deploy_single_proxy" {
  description = "Single instance plus HA"
  default     = true
}

variable "ha-squid_bootstrap_script" {
  description = "Bootstrapt script for ha-squid instances"
  default     = "squid_running_on_docker.sh"
}

variable "ha-squid_extra_vars" {
  description = "additional variables to pass along with the bootstrapscript"
  type        = "list"
  #default     = ["squid_image=master", "squid_version=squid-4.8"]
  default     = ["squid_image=master"]
}

variable "branch" {
  description = "For testing purposes, when something else than the master"
  default     = "master"
}

variable "fence-bot_bucket_access_arns" {
  description = "When fence bot has to access another bucket that wasn't created by the VPC module"
  type        = "list"
  default     = []
}

variable "deploy_ha_squid" {
  description = "Should you want to deploy HA-squid"
  default     = false
}

variable "ha-squid_cluster_desired_capasity" {
  description = "If ha squid is enabled and you want to set your own capasity"
  default     = 2
}

variable "ha-squid_cluster_min_size" {
  description = "If ha squid is enabled and you want to set your own min size"
  default     = 1
}

variable "ha-squid_cluster_max_size" {
  description = "If ha squid is enabled and you want to set your own max size"
  default     = 3
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

variable "single_squid_instance_type" {
  description = "Instance type for the single proxy instance"
  default     = "t2.micro"
}

variable "network_expansion" {
  description = "Let k8s workers be on a /22 subnet per AZ"
  default     = false
}

variable "rds_instance_storage_encrypted"{
  default = true
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

variable "activation_id" {
  default = ""
}

variable "customer_id" {
  default = ""
}

variable "fips" {
  default = false
}
