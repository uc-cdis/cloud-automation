
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
  default = "1.14"
}

variable "workers_subnet_size" {
  default = 24
}

variable "kernel" {
  default = "N/A"
}

variable "bootstrap_script" {
  default = "bootstrap.sh"
}

variable "jupyter_bootstrap_script" {
  default =  "bootstrap.sh"
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

variable "oidc_eks_thumbprint" {
  description = "Thumbprint for the AWS OIDC identity provider"
  type        = "list"
  default     = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

variable "availability_zones" {
  description = "AZ to be used by EKS nodes"
  type        = "list"
  default     = ["us-east-1a", "us-east-1c", "us-east-1d"]
}

variable "domain_test" {
  description = "Domain for the lambda function to check for the proxy"
  default     = "www.google.com"
}

variable "ha_squid" {
  description = "Is HA squid deployed?"
  default     = false
}

variable "dual_proxy" {
  description = "Single instance and HA"
  #default     = false
}

variable "single_az_for_jupyter" {
  description = "Jupyter notebooks on a single AZ"
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  default     = "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic"
}
