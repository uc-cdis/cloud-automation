terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

resource "aws_key_pair" "automation_dev" {
  key_name   = "${var.vpc_name}_automation_dev"
  public_key = "${var.ssh_public_key}"
}

module "cdis_vpc" {
  ami_account_id = "${var.ami_account_id}"
  source         = "../modules/vpc"
  csoc_cidr      = "${var.csoc_cidr}"
  vpc_octet2      = "${var.vpc_octet2}"
  vpc_octet3      = "${var.vpc_octet3}"
  vpc_name       = "${var.vpc_name}"
  ssh_key_name   = "${aws_key_pair.automation_dev.key_name}"
}

#
# Add a bastion node to user vpc.
# Commons VPC is only accessible via CSOC adminvm
#
resource "aws_security_group" "login-ssh" {
  name        = "login-ssh"
  description = "security group that only enables ssh from login node"
  vpc_id      = "${module.cdis_vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.login.private_ip}/32", "${var.csoc_cidr}"]
  }

  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "security group that only enables ssh"
  vpc_id      = "${module.cdis_vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_instance" "login" {
  ami                    = "${module.cdis_vpc.login_ami_id}"
  subnet_id              = "${module.cdis_vpc.public_subnet_id}"
  instance_type          = "t2.micro"
  monitoring             = true
  key_name               = "${aws_key_pair.automation_dev.key_name}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${module.cdis_vpc.security_group_local_id}"]
  iam_instance_profile   = "${module.cdis_vpc.logging_profile_name}"

  tags = {
    Name         = "${var.vpc_name} Login Node"
    Environment  = "${var.vpc_name}"
    Organization = "Basic Service"
  }

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }

  user_data = <<EOF
#!/bin/bash 
sed -i 's/SERVER/login_node-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${var.vpc_name}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = login_node-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${var.vpc_name}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF
}

resource "aws_eip" "login" {
  vpc = true
}

resource "aws_eip_association" "login_eip" {
  instance_id   = "${aws_instance.login.id}"
  allocation_id = "${aws_eip.login.id}"
}
