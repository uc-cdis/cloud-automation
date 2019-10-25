
variable "vpc_name" {}

variable "ec2_keyname" {
  default = "someone@uchicago.edu"
}

variable "instance_type" {
  default = "t3.large"
}

variable "jupyter_instance_type"{
  default = "t3.large"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "peering_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "users_policy" {}


variable "worker_drive_size" {
  default = 30
}

variable "eks_version" {
  default = "1.12"
}

variable "workers_subnet_size" {
  default = 24
}

variable "bootstrap_script" {
  default = "bootstrap-2.0.0.sh"
}

variable "jupyter_bootstrap_script" {
  default = "bootstrap-2.0.0.sh"
}

variable "kernel" {
  default = "N/A"
}

variable "jupyter_worker_drive_size" {
  default = 30
}

variable "cidrs_to_route_to_gw" {
  default = []
}

variable "organization_name" {
  default = "Basic Services"
}

variable "proxy_name" {
  default = " HTTP Proxy"
}

variable "jupyter_asg_desired_capacity" {
  default = 0
}

variable "jupyter_asg_max_size" {
  default = 10
}

variable "jupyter_asg_min_size" {
  default = 0
}
 variable "iam-serviceaccount" {
  default = false
}

variable "availability_zones" {
  description = "AZ to be used by EKS nodes"
  type        = "list"
  default     = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

variable "squid_image_search_criteria" {
  description = "Search criteria for squid AMI look up"
  default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
}

variable "squid_instance_drive_size" {
  description = "Volume size for the squid instance"
  default     = 8
}
