variable "aws_account_id" {
  default = "433568766270"
}

variable "env_vpc_octet3"{
  default = "4"
}

variable "env_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "env_nlb_name" {
  default = "csoc_squid_nlb"
}

# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "099720109477"
}

variable "image_name_search_criteria" {
  default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}

variable "env_pub_subnet_routetable_id" {
  default = "rtb-1cb66860"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}

variable "allowed_principals_list" {
  default = ["arn:aws:iam::707767160287:root"]
}

## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/squid_nlb_central/"
}

variable "bootstrap_script" {
  default = "squidvm.sh"
}

variable "csoc_internal_dns_zone_id"{
  #default = "ZA1HVV5W0QBG1"
}

