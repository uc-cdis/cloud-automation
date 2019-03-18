# id of AWS account that owns the public AMI's

variable "slack_webhook" {
  default = "https://hooks.slack.com/services/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"
}

variable "db_size" 
{
  default = "10"
}

variable "vpc_name" 
{
  default = ""
}

variable "db_fence" 
{
  default = ""
}

variable "db_indexd" 
{
  default = ""
}

variable "db_gdcapi" 
{
  default = ""
}
