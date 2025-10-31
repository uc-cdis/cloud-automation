# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # cdis-test
  default = "707767160287"
}

# the region containing the public source AMI
variable "ami_region" {
  default = "us-east-1"
}

# the name (pattern) of the public source AMI
variable "ami_name" {
  default = "ubuntu16-squid-1.0.2-*"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
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


variable "env_log_group" {
  #default = "common_name"
}

variable "deploy_single_proxy" {
  description = "Should migration to HA-squid is ahead, then deploying in parallel might prevent any downtime"
  default     = false
}

variable "zone_id" {
  description = "Route53 zone in which to create a new record for cloud-proxy.internal.io"
}

variable "instance_type" {
  description = "Instance type of the squid instance"
  default     = "t2.micro"
}

variable "organization_name" {
  description = "For tagging purposes"
  default     = "Basic Service"
}
