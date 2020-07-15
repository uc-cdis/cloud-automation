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
  default = "65.0"
}

variable "slack_webhook" {
 default = ""
}

variable "log_dna_function" {
  default = "arn:aws:lambda:us-east-1:433568766270:function:logdna_cloudwatch"
}

variable "timeout" {
  default = 300
}

variable "memory_size" {
  default = 512
}
