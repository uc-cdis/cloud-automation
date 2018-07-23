variable "vm_name" {
  default = "qualys_scanner"
}

variable "csoc_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "env_vpc_octet3" {
  default = "6"
 }

 variable "qualys_pub_subnet_routetable_id"{
   default = "rtb-7ee06301"
 }

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}

variable "user_perscode"{
  default="123456789"
  }


# id of AWS account that owns the public AMI's
#variable "ami_account_id" {
 # default = "433568766270"
#}




