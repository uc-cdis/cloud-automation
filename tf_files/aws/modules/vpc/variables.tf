# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "707767160287"
}

variable "vpc_name" {}

variable "vpc_octet2" {
  default = 24
}

variable "vpc_octet3" {
  default = 17
}


# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}

variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}


variable "squid-nlb-endpointservice-name" {
  }