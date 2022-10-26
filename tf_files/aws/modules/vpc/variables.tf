# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "099720109477"
}

variable "vpc_name" {}

variable "vpc_cidr_block" {
  default = "172.24.17.0/20"
}


variable "secondary_cidr_block" {
  default = ""
}

variable "vpc_flow_logs" {
  default = false
}

variable "vpc_flow_traffic" {
  default = "ALL"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "peering_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "csoc_managed" {
  default = true
}

# controls whether or not to setup the cloudwatch subscription filter to send logs to CSOC for long term storage
# CTDS uses datadog and this is no longer needed for us.
variable "send_logs_to_csoc" {
  default = true
}

variable "organization_name" {
  description = "for tagging purposes"
  default     = "Basic Service"
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


variable "squid_instance_type" {
  description = "Instance type for HA squid instances"
  default     = "t3.medium"
}

variable "squid_bootstrap_script" {
  description = "Script to run on deployment for the HA squid instances"
  default     = "squid_running_on_docker.sh"
}

variable  "deploy_single_proxy" {
  description = "Single instance plus HA"
  default     = false
}

variable "squid_extra_vars" {
  description = "additional variables to pass along with the bootstrapscript"
  type        = "list"
  #default     = ["squid_image=master"]
}

variable "branch" {
  description = "For testing purposes, when something else than the master"
  default     = "master"
}

variable "fence-bot_bucket_access_arns" {
  description = "When fence bot has to access another bucket that wasn't created by the VPC module"
  type        = "list"
  #default     = []
}

variable "deploy_ha_squid" {
  description = "should you want to deploy HA-squid"
  default     = false
}

variable "squid_cluster_desired_capasity" {
  description = "If ha squid is enabled and you want to set your own capasity"
  default     = 2
}

variable "squid_cluster_min_size" {
  description = "If ha squid is enabled and you want to set your own min size"
  default     = 1
}

variable "squid_cluster_max_size" {
  description = "If ha squid is enabled and you want to set your own max size"
  default     = 3
}

variable "single_squid_instance_type" {
  description = "Single squid instance type"
}

variable "network_expansion" {
  description = "Let k8s wokers use /22 subnets per AZ"
  default     = false
}

variable "activation_id" {
  default = ""
}

variable "customer_id" {
  default = ""
}

variable "slack_webhook" {
  default = ""
}

variable "fips" {
  default = false
}