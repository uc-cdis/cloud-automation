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

variable "aurora_username" {
  description = "aurora username"
  default = ""
}

variable "aurora_hostname" {
  description = "aurora hostname"
  default = ""
}

variable "aurora_password" {
  description = "aurora password"
  default = ""
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

variable "es_endpoint" {
  description = "Elasticsearch endpoint"
  default     = ""
}

variable "es_user_key" {
  description = "Elasticsearch user access key"
  default     = ""
}

variable "es_user_secret" {
  description = "Elasticsearch user secret key"
  default     = ""
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

variable "hostname" {
  description = "hostname of the commons"
  default = ""
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

variable "slack_webhook" {
  description = "Slack webhook"
  default     = ""  
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
  default     = "s3://cdis-gen3-users/dev/user.yaml"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "emalinowskiv1"
}

variable "wts_enabled" {
  description = "Enable wts"
  type        = bool
  default     = true
}

variable "cluster_endpoint" {
 default = ""
}

variable "cluster_ca_cert" {
  default = ""
}

variable "cluster_name" {
  default = ""
}

variable "useryaml_path" {
  
}

variable "gitops_path" {
  
}

variable "fence_config_path" {
  
}

variable "google_client_id" {
  
}

variable "google_client_secret" {
  
}

variable "fence_access_key" {
  
}

variable "fence_secret_key" {

}

variable "upload_bucket" {
  
}

variable "namespace" {
  
}