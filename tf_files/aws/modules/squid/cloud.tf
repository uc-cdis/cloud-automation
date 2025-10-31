# The squid proxy is the first thing that will start sending logs
# to the main loggroup, therefore we have to create it before the instance
# comes up. This group is also the main one for the rest of the entire common
#resource "aws_cloudwatch_log_group" "main_log_group" {
#  name              = "${var.env_vpc_name}"
#  retention_in_days = 1827
#
#  tags = {
#    Environment = "${var.env_vpc_name}"
#  }
#}

###############################################################
# IAM
###############################################################
resource "aws_iam_role" "cluster_logging_cloudwatch" {
  count = "${var.deploy_single_proxy ? 1 : 0 }"
  name  = "${var.env_vpc_name}_cluster_logging_cloudwatch"
  path  = "/"

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

resource "aws_iam_role_policy" "cluster_logging_cloudwatch" {
  count  = "${var.deploy_single_proxy ? 1 : 0 }"
  name   = "${var.env_vpc_name}_cluster_logging_cloudwatch"
  policy = "${data.aws_iam_policy_document.cluster_logging_cloudwatch.json}"
  role   = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}

resource "aws_iam_instance_profile" "cluster_logging_cloudwatch" {
  count  = "${var.deploy_single_proxy ? 1 : 0 }"
  name   = "${var.env_vpc_name}_cluster_logging_cloudwatch"
  role   = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}



###############################################################
# AMI
###############################################################

# configure a dedicated aws provider for the region that contains
# the public source AMI. This allows the usage of other base regions.
provider "aws" {
  alias  = "ami-source-region"
  region = "${var.ami_region}"
}


resource "aws_ami_copy" "squid_ami" {
  count             = "${var.deploy_single_proxy ? 1 : 0 }"
  name              = "${var.env_vpc_name}-${data.aws_ami.public_squid_ami.name}-crypt"
  description       = "An encrypted copy of ${data.aws_ami.public_squid_ami.name}"
  source_ami_id     = "${data.aws_ami.public_squid_ami.id}"
  source_ami_region = "${var.ami_region}"
  encrypted         = true

  tags = {
    Name = "squid-${var.env_vpc_name}"
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

data "aws_ami" "public_squid_ami" {
  provider = "aws.ami-source-region"
  count       = "${var.deploy_single_proxy ? 1 : 0 }"
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.ami_name}"]
  }

  owners = ["${var.ami_account_id}"]
}



###############################################################
# SEC GROUPS 
###############################################################
resource "aws_security_group" "login-ssh" {
  count       = "${var.deploy_single_proxy ? 1 : 0 }"
  name        = "${var.env_vpc_name}-squid-login-ssh"
  description = "security group that only enables ssh from VPC nodes and CSOC"
  vpc_id      = "${var.env_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}", "${var.csoc_cidr}"]
  }

  tags = {
    Environment  = "${var.env_vpc_name}"
    Organization = "${var.organization_name}"
  }

  lifecycle {
    ignore_changes = ["description"]
  }
}

resource "aws_security_group" "proxy" {
  count       = "${var.deploy_single_proxy ? 1 : 0 }"
  name        = "${var.env_vpc_name}-squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id      = "${var.env_vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}"]
  }

  tags = {
    Environment  = "${var.env_vpc_name}"
    Organization = "${var.organization_name}"
  }
}

resource "aws_security_group" "out" {
  count       = "${var.deploy_single_proxy ? 1 : 0 }"
  name        = "${var.env_vpc_name}-squid-out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${var.env_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${var.env_vpc_name}"
    Organization = "${var.organization_name}"
  }
}


###############################################################
# Route53 
###############################################################
resource "aws_route53_record" "squid" {
  count   = "${var.deploy_single_proxy ? 1 : 0 }"
  zone_id = "${var.zone_id}"
  name    = "cloud-proxy"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.proxy.*.private_ip}"]
  lifecycle = {
    ignore_changes = ["records"]
  }
}

###############################################################
# EIP 
###############################################################
resource "aws_eip" "squid" {
  count = "${var.deploy_single_proxy ? 1 : 0 }"
  vpc   = true
}

resource "aws_eip_association" "squid_eip" {
  count         = "${var.deploy_single_proxy ? 1 : 0 }"
  instance_id   = "${aws_instance.proxy.id}"
  allocation_id = "${aws_eip.squid.id}"
}



###############################################################
# EC2 
###############################################################
resource "aws_instance" "proxy" {
  count                  = "${var.deploy_single_proxy ? 1 : 0 }"
  ami                    = "${aws_ami_copy.squid_ami.id}"
  subnet_id              = "${var.env_public_subnet_id}"
  instance_type          = "${var.instance_type}"
  monitoring             = true
  source_dest_check      = false
  key_name               = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.proxy.id}", "${aws_security_group.login-ssh.id}", "${aws_security_group.out.id}"]
#  iam_instance_profile   = "${var.env_instance_profile}" 
  iam_instance_profile   = "${aws_iam_instance_profile.cluster_logging_cloudwatch.name}"

  tags = {
    Name         = "${var.env_vpc_name} HTTP Proxy"
    Environment  = "${var.env_vpc_name}"
    Organization = "${var.organization_name}"
  }

  user_data = <<EOF
#!/bin/bash
echo '127.0.1.1 ${var.env_vpc_name}_squid_proxy' | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname ${var.env_vpc_name}_squid_proxy

sed -i 's/SERVER/http_proxy-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${var.env_log_group}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = http_proxy-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${var.env_log_group}
[squid/access.log]
file = /var/log/squid/access.log*
log_stream_name = http_proxy-squid_access-{hostname}-{instance_id}
log_group_name = ${var.env_log_group}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF

  lifecycle {
    ignore_changes = ["ami", "key_name"]
    create_before_destroy = true
  }
}


