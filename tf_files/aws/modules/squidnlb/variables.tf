variable "aws_account_id" {
  default = "433568766270"
}

variable "env_vpc_octet1"{
  default = "10"
}

variable "env_vpc_octet2"{
  default = "128"
}

variable "env_vpc_octet3"{
  default = "4"
}

variable "env_vpc_id" {
  default = "vpc-e2b51d99"
}

variable "env_nlb_name" {
  default = "csoc_squid_nlb"
}


# id of AWS account that owns the public AMI's
variable "ami_account_id" {
  # cdis-test
  #default = "707767160287"
  default = "099720109477"
}

variable "image_name_search_criteria" {
  default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018*"
}

#variable "csoc_cidr" {
#  default = "10.128.0.0/20"
#}



variable "env_public_subnet_routetable_id" {
  default = "rtb-23b6685f"
}



# name of aws_key_pair ssh key to attach to VM's
variable "ssh_key_name" {
  default = "rarya_id_rsa"
}

#variable "commons_vpc_cidr" {
 # default = "172.16.0.0/12"
#}


variable "allowed_principals_list" {
  type = "list"
  default = ["arn:aws:iam::707767160287:root"]
}

## variable for the bootstrap 
variable "bootstrap_path" {
  default = "cloud-automation/flavors/nginx/"
}

variable "bootstrap_script" {
  #default = "es_revproxy.sh"
}

variable "commons_internal_dns_zone_id"{
  #default = "ZA1HVV5W0QBG1"
}


#variable "env_instance_profile" {
#  default = "common_name_cloudwatch_access_profile"
#}

#variable "env_log_group" {
 # default = "common_name"
#}


#data "aws_iam_policy_document" "squid_logging_cloudwatch" {
 # statement {
  #  actions = [
   #   "logs:CreateLogGroup",
    #  "logs:CreateLogStream",
     # "logs:GetLogEvents",
      #"logs:PutLogEvents",
      #"logs:DescribeLogGroups",
      #"logs:DescribeLogStreams",
      #"logs:PutRetentionPolicy",
    #]

    #effect    = "Allow"
    #resources = ["*"]
  #}
#}





