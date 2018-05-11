resource "aws_cloudwatch_log_group" "csoc_log_group" {
  name              = "${var.vm_hostname}"
  retention_in_days = 1827

  tags {
    Environment  = "${var.environment}"
    Organization = "Basic Services"
  }
}

data "aws_ami" "public_cdis_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu16-docker-base-1.0.2-*"]
  }

  owners = ["${var.ami_account_id}"]
}

resource "aws_ami_copy" "cdis_ami" {
  name              = "ub16-cdis-crypt-1.0.2-nginx"
  description       = "A copy of ubuntu16-docker-base-1.0.2"
  source_ami_id     = "${data.aws_ami.public_cdis_ami.id}"
  source_ami_region = "us-east-1"
  encrypted         = true

  tags {
    Name        = "cdis"
    Environment = "${var.environment}"
  }

  lifecycle {
    #
    # Do not force update when new ami becomes available.
    # We still need to improve our mechanism for tracking .ssh/authorized_keys
    # User can use 'terraform state taint' to trigger update.
    #
    ignore_changes = ["source_ami_id"]
  }
}

# Security group to access peered networks from the csoc admin VM

resource "aws_security_group" "ssh" {
  name        = "ssh_${var.vm_name}"
  description = "security group that only enables ssh"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.environment}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "local" {
  name        = "local_${var.vm_name}"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = "${var.csoc_vpc_id}"

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
    cidr_blocks = ["10.128.0.0/20", "52.0.0.0/8", "54.0.0.0/8", "${var.vpc_cidr_list}"]
  }

  tags {
    Environment = "CSOC"
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

resource "aws_instance" "utility_vm" {
  ami                    = "${aws_ami_copy.cdis_ami.id}"
  subnet_id              = "${var.csoc_subnet_id}"
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

  user_data = <<EOF
#!/bin/bash 

#Proxy configuration and hostname assigment for the adminVM
echo http_proxy=http://cloud-proxy.internal.io:3128 >> /etc/environment
echo https_proxy=http://cloud-proxy.internal.io:3128/ >> /etc/environment
echo no_proxy="localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,search-commons-logs-lqi5sot65fryjwvgp6ipyb65my.us-east-1.es.amazonaws.com"  >> /etc/environment
echo 'Acquire::http::Proxy "http://cloud-proxy.internal.io:3128";' >> /etc/apt/apt.conf.d/01proxy
echo 'Acquire::https::Proxy "http://cloud-proxy.internal.io:3128";' >> /etc/apt/apt.conf.d/01proxy

sudo apt -y update
sudo apt -y upgrade

echo '127.0.1.1 ${var.vm_hostname}' | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname ${var.vm_hostname}

git clone https://github.com/uc-cdis/cloud-automation.git

bash "${var.bootstrap_path}${var.bootstrap_script}" |sudo tee --append /var/log/bootstrapping_script.log

EOF
}
