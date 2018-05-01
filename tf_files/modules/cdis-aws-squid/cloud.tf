# The squid proxy is the first thing that will start sending logs
# to the main loggroup, therefore we have to create it before the instance
# comes up. This group is also the main one for the rest of the entire common
#resource "aws_cloudwatch_log_group" "main_log_group" {
#  name              = "${var.env_vpc_name}"
#  retention_in_days = 1827
#
#  tags {
#    Environment = "${var.env_vpc_name}"
#  }
#}

resource "aws_ami_copy" "squid_ami" {
  name              = "ub16-squid-crypt-${var.env_vpc_name}-1.0.2"
  description       = "A copy of ubuntu16-squid-1.0.2"
  source_ami_id     = "${data.aws_ami.public_squid_ami.id}"
  source_ami_region = "us-east-1"
  encrypted         = true

  tags {
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
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu16-squid-1.0.2-*"]
  }

  owners = ["${var.ami_account_id}"]
}

# Security groups for the CSOC squid proxy

resource "aws_security_group" "login-ssh" {
  name        = "${var.env_vpc_name}-squid-login-ssh"
  description = "security group that only enables ssh from VPC nodes and CSOC"
  vpc_id      = "${var.env_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}", "${var.csoc_cidr}"]
  }

  tags {
    Environment  = "${var.env_vpc_name}"
    Organization = "Basic Service"
  }

  lifecycle {
    ignore_changes = ["description"]
  }
}

resource "aws_security_group" "proxy" {
  name        = "${var.env_vpc_name}-squid-proxy"
  description = "allow inbound tcp at 3128"
  vpc_id      = "${var.env_vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}"]
  }

  tags {
    Environment  = "${var.env_vpc_name}"
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "out" {
  name        = "${var.env_vpc_name}-squid-out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${var.env_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.env_vpc_name}"
    Organization = "Basic Service"
  }
}


# assigning elastic ip to the squid proxy

resource "aws_eip" "squid" {
  vpc = true
}

resource "aws_eip_association" "squid_eip" {
  instance_id   = "${aws_instance.proxy.id}"
  allocation_id = "${aws_eip.squid.id}"
}

resource "aws_instance" "proxy" {
  ami                    = "${aws_ami_copy.squid_ami.id}"
  subnet_id              = "${var.env_public_subnet_id}"
  instance_type          = "t2.micro"
  monitoring             = true
  source_dest_check      = false
  key_name               = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.proxy.id}", "${aws_security_group.login-ssh.id}", "${aws_security_group.out.id}"]
  iam_instance_profile   = "${var.env_instance_profile}" 

  tags {
    Name         = "${var.env_vpc_name} HTTP Proxy"
    Environment  = "${var.env_vpc_name}"
    Organization = "Basic Service"
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
  }
}
