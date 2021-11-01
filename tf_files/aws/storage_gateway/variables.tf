
variable "vpc_name" {}


variable "ami_id" {
  default = ""
}

variable "subnet"{
  default = ""
}

variable "size" {
  default = 80
}

variable "cache_size" {
  default = 150
}
