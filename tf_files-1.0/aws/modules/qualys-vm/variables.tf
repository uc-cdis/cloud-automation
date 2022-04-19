
variable "vm_name" {
  description = "What to name the VM"
#  default     = "qualys_scanner_prod"
}

variable "vpc_id" {
  description = "VPC ID where to deploy the VM"
  default     = "vpc-e2b51d99"
}

variable "env_vpc_subnet" {
  description = "Subnet where the VM will be"
  default     = "10.128.3.0/24"
}

variable "qualys_pub_subnet_routetable_id"{
  description = "Route table to associate the VM with"
  default     = "rtb-7ee06301"
}

# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  description = "Key pair associated with the VM"
  default     = "rarya_id_rsa"
}

variable "user_perscode" {
  description = "Qualys registration code"
  default     = ""
}

variable "image_name_search_criteria" {
  description = "Search criteria to search for AMI"
  default     = "a04e299c-fb8e-4ee2-9a75-94b76cf20fb2"
}


variable "image_desc_search_criteria" {
  description = "Search criteria to search for AMI"
  default     = ""
}

variable "ami_account_id" {
  description = "Account id of the AMI owner"
  default     = "679593333241"
}

variable "organization" {
  description = "Organization for tag puposes"
  default     = "PlanX"
}

variable "environment" {
  description = "Environment for tag purposes"
  default     = "CSOC"
}

variable "instance_type" {
  description = "Instance type for the VM"
  default     = "t3.medium"
}
