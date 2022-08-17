variable "vpc_name" {
  default = ""
}

# If slave setup

variable "parent_account_id" {
  default = ""
}

variable "cur_s3_bucket" {
  default = ""
}

# If master setup

variable "slave_account_id" {
  default = ""
}
