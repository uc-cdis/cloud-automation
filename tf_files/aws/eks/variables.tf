
variable "vpc_name" {}

variable "ec2_keyname" {
  default = "fauzi@uchicago.edu"
}

variable "instance_type" {
  default = "t2.medium"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}

variable "users_folder" {}
