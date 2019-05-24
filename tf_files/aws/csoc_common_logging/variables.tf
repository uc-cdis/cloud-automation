# id of AWS account that owns the public AMI's

variable "csoc_account_id" {
  default = "433568766270"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "child_account_id" {
  # default = "707767160287"
}

variable "child_account_region" {
  default = "us-east-1"
}

variable "common_name" {
  # name of child account - ex: kidsfirst, cdistest  #default = "cdistest"
}

variable "elasticsearch_domain" {
  default = "commons-logs"
}

variable "threshold" {
  default = "4.00"
}

variable "slack_webhook" {
 default = ""
}
