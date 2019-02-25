variable "env_vpc_cidr_octet2"{
  #default = "24"
}

variable "env_vpc_cidr_octet2"{
 # default = "192"
}

variable "env_vpc_name" {
  #default = "raryav1"
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


## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/squid_auto/"
}

variable "bootstrap_script" {
  default = "squidvm.sh"
}







