# https://www.andreagrandi.it/2017/08/25/getting-latest-ubuntu-ami-with-terraform/
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "public" {
  vpc_id = data.aws_vpc.vpc.id

  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

data "aws_security_group" "ssh_in" {
  filter {
      name   = "group-name"
      values = [var.ssh_in_secgroup]
  }
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_security_group" "egress" {
  vpc_id = data.aws_vpc.vpc.id

  filter {
      name   = "group-name"
      values = [var.egress_secgroup]
  }
}