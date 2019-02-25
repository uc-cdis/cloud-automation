
#variable "squid_server_subnet"{
#  default = "172.24.197.0/24"
#}

variable "vpc_octet2"{
  default = "24"
}

variable "vpc_octet3"{
  default = "192"
}


#variable "env_vpc_id" {
#  default = "vpc-0b45c2f1d0ea5bda0"
#}

variable "env_vpc_name" {
  default = "raryav1"
}

variable "env_squid_name" {
  default = "commons_squid_auto"
}


# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  default = "099720109477"
}

variable "image_name_search_criteria" {
  default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"
}

variable "csoc_cidr" {
  default = "10.128.0.0/20"
}



#variable "env_public_subnet_routetable_id" {
#  default = "rtb-09015401a98b3952c"
#}

#variable "env_private_eks_subnet_routetable_id" {
 # default = "rtb-0fc1d4ca429c06d1a"
#}



# name of aws_key_pair ssh key to attach to VM's
#variable "ssh_key_name" {
#  default = "rarya_id_rsa"
#}




#variable "allowed_principals_list" {
#  type = "list"
#  default = ["arn:aws:iam::707767160287:root"]
#}

## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/squid_auto/"
}

variable "bootstrap_script" {
  default = "squidvm.sh"
}

#variable "commons_internal_dns_zone_id"{
 # default = "ZPUZ5CIHT930N"
#}


#variable "squid_subnet_avbl"{
#  default =  "${cidrsubnet("${data.aws_vpc.the_vpc.cidr_block}",4,5)}"
#}





