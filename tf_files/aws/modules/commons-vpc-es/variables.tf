
variable "vpc_name" {}

variable "slack_webhook" {
  default = ""
}

variable "secondary_slack_webhook" {
  default = ""
}

variable "instance_type" {
  default = "m4.large.elasticsearch"
}

variable "ebs_volume_size_gb" {
  default = 20
}