# id of AWS account that owns the public AMI's

variable "csoc_account_id" {
  default = "433568766270"
}

variable "child_account_id" {
  # default = "707767160287"
}

variable "common_name" {
  # name of child account - ex: kidsfirst, cdistest
 # default = "fauziv1"
}

variable "child_account_region" {
  default = "us-east-1"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "elasticsearch_domain" {
  default = "commons-logs"
}

variable "aws_access_key"{
  default = ""
}

variable "aws_secret_key"{
  default = ""
}

variable "threshold"{
  default = "4.00"
}

variable "slack_webhook"{
  default = ""
}
