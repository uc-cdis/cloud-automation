variable "vpc_name" {}

variable "ami_id" {
  default = ""
}

variable "size" {
  default = 80
}

variable "cache_size" {
  default = 150
}

variable "s3_bucket" {
  default = ""
}

variable "key_name" {
  default = ""
}

variable "organization_name" {
  default = "Basic Services"
}
