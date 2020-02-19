resource "aws_cloudwatch_log_group" "csoc_log_group" {
  name              = "${var.vm_hostname}"
  retention_in_days = 1827

  tags {
    Environment  = "${var.environment}"
    Organization = "${var.organization_name}"
  }
}

data "aws_ami" "public_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.image_name_search_criteria}"] 
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter { 
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["${var.ami_account_id}"]
}

resource "aws_ami_copy" "cdis_ami" {
  name              = "${var.vm_name}_ami"
  description       = "A copy of ${data.aws_ami.public_ami.name}"
  source_ami_id     = "${data.aws_ami.public_ami.id}"
  source_ami_region = "${var.aws_region}"
  encrypted         = true

  tags {
    Name        = "cdis"
    Environment = "${var.environment}"
  }

  lifecycle {
    
    # Do not force update when new ami becomes available.
    # We still need to improve our mechanism for tracking .ssh/authorized_keys
    # User can use 'terraform state taint' to trigger update.
    #
    ignore_changes = ["source_ami_id"]
  }
}


# Allo SSH Access 

resource "aws_security_group" "ssh" {
  name        = "ssh_${var.vm_name}"
  description = "security group that only enables ssh"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.environment}"
    Organization = "${var.organization_name}"
    name         = "ssh_${var.vm_name}"
  }
}


# Security group for local traffic

resource "aws_security_group" "local" {
  name        = "local_${var.vm_name}"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.128.0.0/20"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr_list}"]
  }

  tags {
    Environment = "${var.environment}"
    name        = "local_${var.vm_name}"
  }
}

#------- IAM setup ---------------------

#
# basic Role
#
resource "aws_iam_role" "vm_role" {
  name = "${var.vm_name}_role"
  path = "/"

  # https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#
# This guy should only have access to Cloudwatch and nothing more
#
data "aws_iam_policy_document" "vm_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
    ]

    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "vm_policy" {
  name   = "${var.vm_name}_policy"
  policy = "${data.aws_iam_policy_document.vm_policy_document.json}"
  role   = "${aws_iam_role.vm_role.id}"
}

resource "aws_iam_instance_profile" "vm_role_profile" {
  name = "${var.vm_name}_role_profile"
  role = "${aws_iam_role.vm_role.id}"
}

locals {

  proxy_config_environment = <<EOF
http_proxy=http://cloud-proxy.internal.io:3128
https_proxy=http://cloud-proxy.internal.io:3128
no_proxy=localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com
EOF

  proxy_config_apt = <<EOF
Acquire::http::Proxy "http://cloud-proxy.internal.io:3128";
Acquire::https::Proxy "http://cloud-proxy.internal.io:3128";
EOF

}

resource "aws_instance" "utility_vm" {
  ami                    = "${aws_ami_copy.cdis_ami.id}"
  subnet_id              = "${var.vpc_subnet_id}"
  instance_type          = "${var.instance_type}"
  monitoring             = true
  key_name               = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.local.id}"]

  iam_instance_profile = "${aws_iam_instance_profile.vm_role_profile.name}"

  tags {
    Name        = "${var.vm_name}"
    Environment = "${var.environment}"
  }

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }

  provisioner "file" {
    content     = "${var.proxy == "yes" ? local.proxy_config_environment : ""}"
    destination = "/tmp/environment"
    connection {
      type     = "ssh"
      user     = "ubuntu"
    }
  }

  provisioner "file" {
    content     = "${var.proxy == "yes" ? local.proxy_config_apt : ""}"
    destination = "/tmp/01proxy"
    connection {
      type     = "ssh"
      user     = "ubuntu"
    }
  }

  user_data = <<EOF
#!/bin/bash 

#Proxy configuration and hostname assigment for the adminVM
#echo http_proxy=http://cloud-proxy.internal.io:3128 >> /etc/environment
#echo https_proxy=http://cloud-proxy.internal.io:3128/ >> /etc/environment
#echo no_proxy="localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com"  >> /etc/environment
#echo 'Acquire::http::Proxy "http://cloud-proxy.internal.io:3128";' >> /etc/apt/apt.conf.d/01proxy
#echo 'Acquire::https::Proxy "http://cloud-proxy.internal.io:3128";' >> /etc/apt/apt.conf.d/01proxy

cat /tmp/environment >> /etc/environment
cat /tmp/01proxy >> /etc/apt/apt.conf.d/01proxy

cd /home/ubuntu
sudo git clone https://github.com/uc-cdis/cloud-automation.git
sudo chown -R ubuntu. cloud-automation

#sudo mkdir -p /root/.ssh/
#sudo cat cloud-automation/files/authorized_keys/ops_team | sudo tee --append /home/ubuntu/.ssh/authorized_keys
sudo cat cloud-automation/${var.authorized_keys} | sudo tee --append /home/ubuntu/.ssh/authorized_keys


echo '127.0.1.1 ${var.vm_hostname}' | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname ${var.vm_hostname}

sudo apt -y update
sudo DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade| sudo tee --append /var/log/bootstrapping_script.log

sudo apt-get autoremove -y
sudo apt-get clean
sudo apt-get autoclean

cd /home/ubuntu


sudo bash "${var.bootstrap_path}${var.bootstrap_script}" ${join(";",var.extra_vars)} 2>&1 |sudo tee --append /var/log/bootstrapping_script.log

EOF
}
