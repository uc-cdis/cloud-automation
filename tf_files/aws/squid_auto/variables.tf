variable "env_vpc_cidr"{
  default = "172.24.192.0/20"
}

variable "squid_proxy_subnet"{
  default = "172.24.197.0/24"
}

variable "env_vpc_name" {
  #default = "raryav1"
}

variable "env_squid_name" {
 # default = "commons_squid_auto"
}

# id of AWS account that owns the public AMI's

variable "ami_account_id" {
  default = "099720109477"
}

variable "image_name_search_criteria" {
  default = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "secondary_cidr_block" {
}

## variable for the bootstrap 

variable "bootstrap_path" {
  default = "cloud-automation/flavors/squid_auto/"
}

variable "bootstrap_script" {
  default = "squid_running_on_docker.sh"
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

variable "squid_instance_drive_size" {
  description = "Size of the root volume for the instance"
  default     = 8
}

variable "squid_availability_zones" {
  description = "AZs on wich to associate the routes for the squid proxies"
  type        = "list"
}

variable "main_public_route" {
  description = "The route table that allows public access"
}

variable "private_kube_route" {
  description = "public kube route table id"
}

variable "route_53_zone_id" {
  description = "DNS zone for .internal.io"
}

variable "branch" {
  description = "branch to use in bootstrap script"
  default     = "master"
}

variable "extra_vars" {
  description = "additional variables to pass along with the bootstrapscript"
  type        = "list"
  default     = ["squid_image=master"]
}

variable "cluster_desired_capasity" {
  default = 2
}

variable "cluster_max_size" {
  default = 3
}

variable "cluster_min_size" {
  default = 1
}

variable "network_expansion" {
  default = true
}

variable "deploy_ha_squid" {
  default = true
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
