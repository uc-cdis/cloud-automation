variable "vpc_name" {}

variable "environment" {}

variable "cloudwatchlogs_group" {}

variable "deploy_cloud_trail" {
  default = true
}
