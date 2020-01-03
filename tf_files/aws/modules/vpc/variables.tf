# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "707767160287"
}

variable "vpc_name" {}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "squid-nlb-endpointservice-name" {
  default = "com.amazonaws.vpce.us-east-1.vpce-svc-0ce2261f708539011"
}

variable "csoc_managed" {
  default = "yes"
}

variable "organization_name" {
  default = "Basic Service"
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

variable "private_kube_route" {
  description = "Id of the route fo plublic_kube subnet"
}

variable "squid_instance_type" {
  description = "Instance type for HA squid instances"
  default     = "t3.medium"
}
