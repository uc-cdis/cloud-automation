variable "aws_region" {
  default = "us-east-1"
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # cdis-test
  default = "707767160287"
}

variable "csoc_account_id" {
  default = "what.it.is"
}

variable "csoc_vpc_id" {
  default = "what.it.is"
}

variable "csoc_subnet_id" {
  default = "what.it.is"
}

variable "child_account_id" {}

variable "child_name" {
  # name of child account - ex: kidsfirst, cdistest
}

variable "vpc_cidr_octet" {
  # cidr_block = "172.24.${var.vpc_octet + 0}.0/24"
  default = 17
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "master_key"
}
