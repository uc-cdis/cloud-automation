
variable "vpc_name" {
}

variable "bucket_name" {
}

variable "bucket_access_arns" {
  description = "When fence bot has to access another bucket that wasn't created by the VPC module"
  type        = "list"
  default     = []
}
