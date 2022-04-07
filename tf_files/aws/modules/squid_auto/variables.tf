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
  default = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
}

variable "peering_cidr" {
  default = "10.128.0.0/20"
}

variable "secondary_cidr_block" {
  default = ""
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

variable "deploy_ha_squid" {
  description = "Should this module be deployed"
  default     = true
}

variable "cluster_desired_capasity" {
  description = "Desired capasity for the ha squid proxy"
  default     = 2
}

variable "cluster_max_size" {
  description = "Max size of the autoscaling group"
  default     = 3
}

variable "cluster_min_size" { 
  description = "Min size of the autoscaling group"
  default     = 1
}

variable "network_expansion" {
  description = "let k8s workers run on a /22 subnet"
  default     = false
}

variable "squid_depends_on" { 
  default = "" 
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

# the key that was used to encrypt the FIPS enabled AMI
# This is needed so ASG can decrypt the ami
variable "fips_ami_kms" {
  default = "arn:aws:kms:us-east-1:707767160287:key/mrk-697897f040ef45b0aa3cebf38a916f99"
}

variable "fips" {
  default = false
}
