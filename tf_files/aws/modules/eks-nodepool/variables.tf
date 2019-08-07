
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

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}

variable "users_policy" {}

variable "nodepool" {
  default = "jupyter"
}

variable "eks_cluster_ca" {
  default = ""
}

variable "eks_cluster_endpoint" {
  default = ""
}

variable "eks_private_subnets" {
  type  = "list"
}

variable "control_plane_sg" {}

variable "default_nodepool_sg" {}

variable "deploy_jupyter_pool" {
  default = "no"
}

variable "eks_version" {}

variable "kernel" {
  default = "N/A"
}

variable "bootstrap_script" {
  default = "bootstrap-2.0.0.sh"
}

variable "jupyter_worker_drive_size" {
  default = 30
}

variable "organization_name" {
  default = "Basic Service"
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
