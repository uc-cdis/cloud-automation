# id of AWS account that owns the public AMI's
variable "ami_account_id" {
    default = "707767160287"
}

variable "vpc_name" {
}

variable "vpc_octet" {
    default = 17
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
}
