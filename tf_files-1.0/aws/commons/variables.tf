variable "vpc_name" {
  default = "Commons1"
}

variable "iam_role_name" {
  default = "csoc_adminvm"
}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
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

variable "db_password_fence" {
  default = ""
  sensitive = true
}

variable "db_password_peregrine" {
  default = ""
  sensitive = true  
}

variable "db_password_sheepdog" {
  default = ""
  sensitive = true
}

variable "db_password_indexd" {
  default = ""
  sensitive = true
}

variable "portal_app" {
  # passed through to portal's APP environment to customize for environment
  default = "dev"
}

variable "fence_snapshot" {
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

variable "kube_ssh_key" {
  default = ""
}

/* A list of ssh keys that will be added to
   kubernete nodes, Example:
   '- ssh-rsa XXXX\n - ssh-rsa XXX' */
variable "kube_additional_keys" {
  default = ""
}

# 32 alphanumeric characters
variable "hmac_encryption_key" {
  default = ""
  sensitive = true
}

variable "sheepdog_secret_key" {
  default = ""
  sensitive = true
}

# password for write access to indexd
variable "sheepdog_indexd_password" {
  default = ""
  sensitive = true
}

#
# DEPRECATED - should no longer be necessary
# gdcapi's oauth2 client id (fence as oauth2 provider)
#
variable "sheepdog_oauth2_client_id" {
  default = ""
  sensitive = true
}

variable "config_folder" {
  # Object folder of user.yaml file - ex: s3://cdis-gen3-users/${config_folder}/user.yaml
  default = "dev"
}

#
# DEPRECATED - should no longer be necessary
# gdcapi's oauth2 client id (fence as oauth2 provider)
#
variable "sheepdog_oauth2_client_secret" {
  default = ""
  sensitive = true
}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "099720109477"
}

variable "squid_image_search_criteria" {
  description = "Search criteria for squid AMI look up"
  default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-20.04-amd64-server-*"
}

variable "peering_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "squid-nlb-endpointservice-name" {
  default = "com.amazonaws.vpce.us-east-1.vpce-svc-0ce2261f708539011"
  }

locals {
  # kube-aws does not like '-' in cluster name
  cluster_name = "${replace(var.vpc_name, "-", "")}"
}

variable "slack_webhook" {
  default = ""
  sensitive = true
}

variable "secondary_slack_webhook" {
  default = ""
  sensitive = true
}

variable "alarm_threshold" {
  default = "85"
}


variable "csoc_managed" {
  default = false
}

variable "csoc_peering" {
  default = false
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

variable "engine_version" {
  default = "13" 
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
  default     = 20
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
  default     = ["squid_image=master"]
}

variable "branch" {
  description = "For testing purposes, when something else than the master"
  default     = "master"
}

variable "fence-bot_bucket_access_arns" {
  description = "When fence bot has to access another bucket that wasn't created by the VPC module"
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
  sensitive = true
}

variable "customer_id" {
  default = ""
  sensitive = true
}

variable "fips" {
  default = false
}

variable "ignore_fence_changes" {
  default = ["engine_version","storage_encrypted","identifier"]
}

variable "ignore_sheepdog_changes" {
  default = ["engine_version","storage_encrypted","identifier"]
}

variable "ignore_indexd_changes" {
  default = ["engine_version","storage_encrypted","identifier"]
}

variable "prevent_fence_destroy" {
  default = true
}

variable "prevent_sheepdog_destroy" {
  default = true
}
variable "prevent_indexd_destroy" {
  default = true
}

variable "deploy_alarms" {
  default = true
}

variable "ec2_keyname" {
  default = "someone@uchicago.edu"
}

variable "instance_type" {
  default = "t3.large"
}

variable "jupyter_instance_type"{
  default = "t3.large"
}

variable "workflow_instance_type"{
  default = "t3.2xlarge"
}

variable "secondary_cidr_block" {
  default = ""
}

variable "users_policy" {}


variable "worker_drive_size" {
  default = 30
}

variable "eks_version" {
  default = "1.25"
}

variable "workers_subnet_size" {
  default = 24
}

variable "bootstrap_script" {
  default = "bootstrap-with-security-updates.sh"
}

variable "jupyter_bootstrap_script" {
  default = "bootstrap-with-security-updates.sh"
}

variable "kernel" {
  default = "N/A"
}

variable "jupyter_worker_drive_size" {
  default = 30
}

variable "workflow_bootstrap_script" {
  default =  "bootstrap.sh"
}

variable "workflow_worker_drive_size" {
  default = 30
}

variable "cidrs_to_route_to_gw" {
  default = []
}

variable "organization_name" {
  default = "Basic Services"
}

variable "jupyter_asg_desired_capacity" {
  default = 0
}

variable "jupyter_asg_max_size" {
  default = 10
}

variable "jupyter_asg_min_size" {
  default = 0
}

variable "workflow_asg_desired_capacity" {
  default = 0
}

variable "workflow_asg_max_size" {
  default = 50
}

variable "workflow_asg_min_size" {
  default = 0
}

variable "iam-serviceaccount" {
  default = true
}

variable "domain_test" {
  description = "url for the lambda function to check for the proxy"
  default     = "www.google.com"
}

variable "deploy_workflow" {
  description = "Deploy workflow nodepool?"
  default     = false
}

variable "secondary_availability_zones" {
  description = "AZ to be used by EKS nodes in the secondary subnet"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
}

variable "deploy_jupyter" {
  description = "Deploy workflow nodepool?"
  default     = true
}

variable "dual_proxy" {
  description = "Single instance and HA"
  default     = false
}

variable "single_az_for_jupyter" {
  description = "Jupyter notebooks on a single AZ"
  default     = false
}

variable "oidc_eks_thumbprint" {
  description = "Thumbprint for the AWS OIDC identity provider"
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  default     = "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic"
}

# the key that was used to encrypt the FIPS enabled AMI
# This is needed to ASG can decrypt the ami 
variable "fips_ami_kms" {
  default = "arn:aws:kms:us-east-1:707767160287:key/mrk-697897f040ef45b0aa3cebf38a916f99"
}

# This is the FIPS enabled AMI in cdistest account.
variable "fips_enabled_ami" {
  default = "ami-0de87e3680dcb13ec"
}

variable "availability_zones" {
  description = "AZ to be used by EKS nodes"
  default     = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

variable "deploy_eks" {
  default = true
}

variable "deploy_es" {
  default = true
}

variable "ebs_volume_size_gb" {
  default = 20
}

variable "encryption" {
  default = "true"
}

variable "es_instance_type" {
  default = "m4.large.elasticsearch"
}

variable "es_instance_count" {
  default = 3
}

variable "es_version" {
  description = "What version to use when deploying ES"
  default     = "6.8"
}

variable "es_linked_role" {
  description = "Whether or no to deploy a linked roll for ES"
  default     = true
}

### Aurora

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
  default     = 32
}

variable "deploy_aurora" {
  default = false
}

variable "deploy_rds" {
  default = true
}

variable "use_asg" {
  default = true
} 

variable "use_karpenter" {
  default = false
}

variable "karpenter_version" {
  default = "v0.24.0"
}

variable "deploy_cloud_trail" {
  default = true
}

variable "send_logs_to_csoc" {
  default = true
}

variable "route_table_name" {
  default = "eks_private"
}

variable "eks_public_access" {
  default = "true"
}

#### helm chart values

variable "deploy_gen3" {
  default = false
}

variable "ambassador_enabled" {
  description = "Enable ambassador"
  type        = bool
  default     = true
}

variable "arborist_enabled" {
  description = "Enable arborist"
  type        = bool
  default     = true
}

variable "argo_enabled" {
  description = "Enable argo"
  type        = bool
  default     = true
}

variable "audit_enabled" {
  description = "Enable audit"
  type        = bool
  default     = true
}

variable "aws-es-proxy_enabled" {
  description = "Enable aws-es-proxy"
  type        = bool
  default     = true
}

variable "dbgap_enabled" {
  description = "Enable dbgap sync in the usersync job"
  type        = bool
  default     = false
}

variable "dd_enabled" {
  description = "Enable datadog"
  type        = bool
  default     = false
}

variable "dictionary_url" {
  description = "URL to the data dictionary"
  default     = ""
}

variable "dispatcher_job_number" {
  description = "Number of dispatcher jobs"
  default     = 10
}

variable "fence_enabled" {
  description = "Enable fence"
  type        = bool
  default     = true
}

variable "guppy_enabled" {
  description = "Enable guppy"
  type        = bool
  default     = true
}

variable "hatchery_enabled" {
  description = "Enable hatchery"
  type        = bool
  default     = true
}

variable "indexd_enabled" {
  description = "Enable indexd"
  type        = bool
  default     = true
}

variable "indexd_prefix" {
  description = "Indexd prefix"
  default     = "dg.XXXX/"
}

variable "ingress_enabled" {
  description = "Create ALB ingress"
  type        = bool
  default     = true
}

variable "manifestservice_enabled" {
  description = "Enable manfiestservice"
  type        = bool
  default     = true
}

variable "metadata_enabled" {
  description = "Enable metadata"
  type        = bool
  default     = true
}

variable "netpolicy_enabled" {
  description = "Enable network policy security rules"
  type        = bool
  default     = false
}

variable "peregrine_enabled" {
  description = "Enable perergrine"
  type        = bool
  default     = true
}

variable "pidgin_enabled" {
  description = "Enable pidgin"
  type        = bool
  default     = true
}

variable "portal_enabled" {
  description = "Enable portal"
  type        = bool
  default     = true
}

variable "public_datasets" {
  description = "whether the datasets are public"
  type        = bool
  default     = false
}

variable "requestor_enabled" {
  description = "Enable requestor"
  type        = bool
  default     = true
}

variable "revproxy_arn" {
  description = "ARN for the revproxy cert in ACM"
  default     = ""
}

variable "revproxy_enabled" {
  description = "Enable revproxy"
  type        = bool
  default     = true
}

variable "sheepdog_enabled" {
  description = "Enable sheepdog"
  type        = bool
  default     = true
}

variable "slack_send_dbgap" {
  description = "Enable slack message for usersync job"
  type        = bool
  default     = false
}

variable "ssjdispatcher_enabled" {
  description = "Enable ssjdispatcher"
  type        = bool
  default     = true
}

variable "tier_access_level" {
  description = "Tier access level for guppy"
  default     = "private"
}

variable "tier_access_limit" {
  description = "value for tier access limit"
  default     = "100"
}

variable "usersync_enabled" {
  description = "Enable usersync cronjob"
  type        = bool
  default     = true
}

variable "usersync_schedule" {
  description = "Cronjob schedule for usersync"
  default     = "*/30 * * * *"
}

variable "useryaml_s3_path" {
  description = "S3 path to the user.yaml file"
  default     = "https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json"
}

variable "wts_enabled" {
  description = "Enable wts"
  type        = bool
  default     = true
}

variable "fence_config_path" {
  default = ""
}

variable "useryaml_path" {
  default = ""
}

variable "gitops_path" {
  default = "https://github.com/uc-cdis/cdis-manifest.git"
}

variable "google_client_id" {
  default = ""
  sensitive = true
}

variable "google_client_secret" {
  default = ""
  sensitive = true
}

variable "fence_access_key" {
  default = ""
  sensitive = true
}

variable "fence_secret_key" {
  default = ""
  sensitive = true
}

variable "upload_bucket" {
  default = ""
}

variable "namespace" {
  default = "default"
}

variable "secrets_manager_enabled" {
  default = false
}

variable "ci_run" {
  default = false
}

variable "commons_log_retention" {
  description = "value in days for the cloudwatch log retention period"
  default = "3653"
}
