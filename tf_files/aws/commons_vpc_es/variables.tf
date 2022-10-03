
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

variable "es_version" {
  description = "What version to use when deploying ES"
  default     = "6.8"
}

variable "es_linked_role" {
  description = "Whether or no to deploy a linked roll for ES"
  default     = true
}
