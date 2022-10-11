# id of AWS account that owns the public AMI's

variable "ami_account_id" {
  # cdis-test
  default = "707767160287"
}

#pass on the environment name

variable "env_vpc_name" {
  #default="csoc_main"
}

variable "env_public_subnet_id" {
  # default="subnet-da2c0a87"
}

# name of aws_key_pair ssh key to attach to VM's

variable "ssh_key_name" {
  default = "rarya_id_rsa"
}

variable "env_vpc_cidr" {
  #default = "10.128.0.0/20"
}

variable "env_vpc_id" {
  #default = "vpc-e2b51d99"
}

variable "instance_type" {
  description = "Instance type for the squid instance"
  default     = "t2.micro"
}
