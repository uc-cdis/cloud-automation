# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # cdis-test
  default = "707767160287"
}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "csoc_subnet_id" {
  default = "subnet-6127013c"
}

variable "child_account_id" {
  # default = "707767160287"
}

variable "child_name" {
  # name of child account - ex: kidsfirst, cdistest  # default = "cdistest"
}

variable "child_account_region" {
  default = "us-east-1"
}

#variable "secgroup_adminvms" {
#  default = "sg-9f56cfe9"
#}

variable "aws_region" {
  default = "us-east-1"
}

variable "elasticsearch_domain" {
  default = "commons-logs"
}

variable "vpc_cidr_list" {
  type = "list"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}
