# id of AWS account that owns the public AMI's

variable "slack_webhook" {
  default = ""
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
