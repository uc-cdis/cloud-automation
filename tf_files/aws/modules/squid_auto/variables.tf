variable "env_vpc_cidr"{
  description = "CIDR of the VPC where this cluster will reside"
  #default     = 172.24.192.0/20
}

variable "squid_proxy_subnet"{
  #default = 172.24.197.0/24
}

variable "env_vpc_name" {
  #default = "raryav1"
}

variable "env_squid_name" {
  #default = "commons_squid_auto"
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

## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/squid_auto/"
}

variable "bootstrap_script" {
  default = "squidvm.sh"
}

variable "squid_instance_type" {
  description = "instance type that replicas of squid will be deployed into"
  default     = "t3.medium"
}

variable "organization_name" {
  description = "basically for tagging porpuses"
  default     = "Basic Services"
}

variable "env_log_group" {
  description = "log group in which to send logs from the instance"
}

variable "env_vpc_id" {
  description = "the vpc id where the proxy cluster will reside"
}

variable "ssh_key_name" {
  description = "ssh key name that instances in the cluster will use"
}

variable "eks_private_route_table_id" {
  description = "routing table for the EKS private subnet"
}

variable "squid_instance_drive_size" { 
  description = "Size of the root volume for the instance"
  default     = 8
}
