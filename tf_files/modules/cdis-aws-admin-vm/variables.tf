# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # cdis-test
  default = "707767160287"
}

variable "csoc_account_id" {
  default = "433568766270"
}

variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "csoc_subnet_id" {
  default = "subnet-6127013c"
}

variable "child_account_id" {
  # default = "707767160287"

}

variable "child_name" {
  # name of child account - ex: kidsfirst, cdistest
 # default = "cdistest"
}

variable "vpc_cidr_octet" {
  # cidr_block = "172.24.${var.vpc_octet + 0}.0/24"
  # default = 16
}

variable "aws_access_key" 
{
  default = ""
}

variable "aws_secret_key" 
{
  default = ""
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}
