
variable "vpc_name" {}

variable "ec2_keyname" {
  default = "someone@uchicago.edu"
}

variable "instance_type" {
  default = "t2.medium"
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
