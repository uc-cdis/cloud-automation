variable "vpc_name" {}

variable "instance_type" {
  default = "t3.small"
}

variable "instance_count" {
  default = 5
}

variable "ssh_public_key" {
}
