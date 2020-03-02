
variable "vpc_name" {}

variable "slack_webhook" {
  default = ""
}
variable "secondary_slack_webhook" {
  default  = ""
}

variable "instance_type" {
  default = "m4.large.elasticsearch"
}

variable "ebs_volume_size_gb" {
  default = 20
}

variable "encryption" {
  default = "true"
}

variable "instance_count" {
  default = 3
}

variable "organization_name" {
  description = "For tagging purposes"
  default     = "Basic Service"
}
