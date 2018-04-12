variable "vpc_name" {
  default = "Commons1"
}

variable "vpc_octet" {
  default = 14
}

variable "aws_region" {
  default = "us-east-1"
}

variable "ssh_public_key" {}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "707767160287"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}
