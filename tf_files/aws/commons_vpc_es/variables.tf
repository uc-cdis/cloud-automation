
variable "vpc_name" {}
variable "slack_webhook" {}
variable "secondary_slack_webhook" {}

variable "instance_type" {
  default = "m4.large.elasticsearch"
}

variable "ebs_volume_size_gb" {
  default = 20
}