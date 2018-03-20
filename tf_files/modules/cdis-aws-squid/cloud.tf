resource "aws_cloudwatch_log_group" "squid_log_group" {
  name              = "master_squid"
  retention_in_days = 1827

  tags {
    Environment = "${var.environment_name}"
  }
}

resource "aws_ami_copy" "squid_ami" {
  name              = "ub16-squid-crypt-${var.environment_name}-1.0.2"
  description       = "A copy of ubuntu16-squid-1.0.2"
  source_ami_id     = "${data.aws_ami.public_squid_ami.id}"
  source_ami_region = "us-east-1"
  encrypted         = true

  tags {
    Name = "squid-${var.environment_name}"
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
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu16-squid-1.0.2-*"]
  }

  owners = ["${var.ami_account_id}"]
}

# Security groups for the CSOC squid proxy

resource "aws_security_group" "login-ssh" {
  name        = "csoc-squid-login-ssh"
  description = "security group that only enables ssh from login node"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${var.csoc_cidr}"]
  }

  tags {
    Environment  = "${var.environment_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "proxy" {
  name        = "csoc-squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id      = "${var.csoc_vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["${var.csoc_cidr}"]
  }

  tags {
    Environment  = "${var.environment_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "out" {
  name        = "csoc-squid-out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${var.csoc_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.environment_name}"
    Organization = "Basic Service"
  }
}

#logging for the squid proxy
resource "aws_iam_role" "cluster_logging_cloudwatch" {
  name = "${var.environment_name}_cluster_logging_cloudwatch"
  path = "/"

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
  name   = "${var.environment_name}_cluster_logging_cloudwatch"
  policy = "${data.aws_iam_policy_document.cluster_logging_cloudwatch.json}"
  role   = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}

resource "aws_iam_instance_profile" "cluster_logging_cloudwatch" {
  name = "${var.environment_name}_cluster_logging_cloudwatch"
  role = "${aws_iam_role.cluster_logging_cloudwatch.id}"
}


# assigning elastic ip to the squid proxy

resource "aws_eip" "squid" {
  vpc = true
}


resource "aws_eip_association" "squid_eip" {
    instance_id = "${aws_instance.proxy.id}"
    allocation_id = "${aws_eip.squid.id}"
}

resource "aws_instance" "proxy" {
  ami                    = "${aws_ami_copy.squid_ami.id}"
  subnet_id              = "${var.public_subnet_id}"
  instance_type          = "t2.micro"
  monitoring             = true
  source_dest_check      = false
  key_name               = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.proxy.id}", "${aws_security_group.login-ssh.id}", "${aws_security_group.out.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.cluster_logging_cloudwatch.name}"

  tags {
    Name         = "${var.environment_name} HTTP Proxy"
    Environment  = "${var.environment_name}"
    Organization = "Basic Service"
  }

  user_data = <<EOF
#!/bin/bash
sed -i 's/SERVER/http_proxy-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${var.environment_name}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = http_proxy-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = "${aws_cloudwatch_log_group.squid_log_group.name}"
[squid/access.log]
log_group_name = "${aws_cloudwatch_log_group.squid_log_group.name}"
log_stream_name = http_proxy-squid_access-{hostname}-{instance_id}
file = /var/log/squid/access.log*
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF

  lifecycle {
    ignore_changes = ["ami", "key_name"]
  }
}
