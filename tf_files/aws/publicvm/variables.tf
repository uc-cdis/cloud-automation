variable "vpc_name" {
  default = "vadcprod"
}

variable "instance_type" {
  default = "t3.small"
}

variable "ssh_in_secgroup" {
  default = "ssh_eks_vadcprod"
}

variable "egress_secgroup" {
  default = "out"
}

variable "subnet_name" {
  default = "public"
}

variable "volume_size" {
  default = 500
}

variable "policies" {
  default = []
  type    = "list"
}

variable "ami" {
  default = ""
}

variable "vm_name" {
}
