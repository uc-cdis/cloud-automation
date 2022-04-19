### DATA RESOURCES:

#Basics

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ami" "public_squid_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.image_name_search_criteria]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = [var.ami_account_id]

}
