### Logging stuff

resource "aws_iam_instance_profile" "squid-nlb_role_profile" {
  name = "${var.env_nlb_name}_squid-nlb_role_profile"
  role = "${aws_iam_role.squid-nlb_role.id}"
}


resource "aws_cloudwatch_log_group" "squid-nlb_log_group" {
  name              = "${var.env_nlb_name}_log_group"
  retention_in_days = 1827

  tags {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Services"
  }
}


resource "aws_iam_role" "squid-nlb_role" {
  name = "${var.env_nlb_name}_role"
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


#Launching the private subnets for the squid VMs

data "aws_availability_zones" "available" {}


resource "aws_subnet" "squid_priv0" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.0/27"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_priv0", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_priv1" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.32/27"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_priv1", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_priv2" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.64/27"
  availability_zone = "${data.aws_availability_zones.available.names[2]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_priv2", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_priv3" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.96/27"
  availability_zone = "${data.aws_availability_zones.available.names[3]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_priv3", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_priv4" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.128/27"
  availability_zone = "${data.aws_availability_zones.available.names[4]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_priv4", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_priv5" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.160/27"
  availability_zone = "${data.aws_availability_zones.available.names[5]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_priv5", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}


resource "aws_route_table_association" "squid_nlb0" {
  #subnet_id      = ["${aws_subnet.squid_priv0.id}, ${aws_subnet.squid_priv1.id},${aws_subnet.squid_priv2.id},${aws_subnet.squid_priv3.id},${aws_subnet.squid_priv4.id},${aws_subnet.squid_priv5.id}"]
  subnet_id      = "${aws_subnet.squid_priv0.id}"
  route_table_id = "${var.env_priv_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb1" {
  subnet_id      = "${aws_subnet.squid_priv1.id}"
  route_table_id = "${var.env_priv_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb2" {
  subnet_id      = "${aws_subnet.squid_priv2.id}"
  route_table_id = "${var.env_priv_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb3" {
  subnet_id      = "${aws_subnet.squid_priv3.id}"
  route_table_id = "${var.env_priv_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb4" {
  subnet_id      = "${aws_subnet.squid_priv4.id}"
  route_table_id = "${var.env_priv_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb5" {
  subnet_id      = "${aws_subnet.squid_priv5.id}"
  route_table_id = "${var.env_priv_subnet_routetable_id}"
}


# launching the network load balancer for the squid VMs

resource "aws_lb" "squid_nlb" {
  name               = "${var.env_nlb_name}-prod"
  internal           = true
  load_balancer_type = "network"
  #subnets            = ["${aws_subnet.squid_priv0.id}, ${aws_subnet.squid_priv1.id}, ${aws_subnet.squid_priv2.id}, ${aws_subnet.squid_priv3.id}, ${aws_subnet.squid_priv4.id}, ${aws_subnet.squid_priv5.id} "]
  subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_priv0.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_priv1.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_priv2.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_priv3.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_priv4.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_priv5.id}"
  }

  enable_deletion_protection = true
  enable_cross_zone_load_balancing = true

  tags {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "squid_nlb" {
  name     = "${var.env_nlb_name}-prod-tg"
  port     = 3128
  protocol = "TCP"
  vpc_id   = "${var.env_vpc_id}"
}

resource "aws_lb_listener" "squid_nlb" {
  load_balancer_arn = "${aws_lb.squid_nlb.arn}"
  port              = "3128"
  protocol          = "TCP"
  default_action {
    target_group_arn = "${aws_lb_target_group.squid_nlb.arn}"
    type             = "forward"
  }
}


## Enpoint service for squid nlb

resource "aws_vpc_endpoint_service" "squid_nlb" {
  acceptance_required =  true
  network_load_balancer_arns = ["${aws_lb.squid_nlb.arn}"]
  #availability_zones = ["us-east-1a","us-east-1b","us-east-1c","us-east-1d","us-east-1e","us-east-1f"]
  allowed_principals = "${var.allowed_principals_list}"
}



# Auto scaling group for squid nlb

resource "aws_launch_configuration" "squid_nlb" {
  name_prefix = "${var.env_nlb_name}_autoscaling_launch_config"
  image_id = "${data.aws_ami.public_squid_ami.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.squidnlb_in.id}", "${aws_security_group.squidnlb_out.id}"]
  key_name = "${var.ssh_key_name}"
  iam_instance_profile   = "${aws_iam_instance_profile.squid-nlb_role_profile.name}"

user_data = <<EOF
#!/bin/bash
echo '127.0.1.1 ${var.env_nlb_name}_{instance_id}' | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname ${var.env_nlb_name}_{instance_id}

sed -i 's/SERVER/http_proxy-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${aws_cloudwatch_log_group.squid-nlb_log_group.name}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = http_proxy-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${aws_cloudwatch_log_group.squid-nlb_log_group.name}
[squid/access.log]
file = /var/log/squid/access.log*
log_stream_name = http_proxy-squid_access-{hostname}-{instance_id}
log_group_name = ${aws_cloudwatch_log_group.squid-nlb_log_group.name}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF

lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "squid_nlb" {
  name = "${var.env_nlb_name}_autoscaling_grp"
  availability_zones = ["us-east-1a","us-east-1b","us-east-1c","us-east-1d","us-east-1e","us-east-1f"]
  desired_capacity = 4
  max_size = 6
  min_size = 1
  target_group_arns = ["${aws_lb_target_group.squid_nlb.arn}"]
  vpc_zone_identifier = ["${aws_subnet.squid_priv0.id}", "${aws_subnet.squid_priv1.id}", "${aws_subnet.squid_priv2.id}", "${aws_subnet.squid_priv3.id}", "${aws_subnet.squid_priv4.id}", "${aws_subnet.squid_priv5.id}"]
  launch_configuration = "${aws_launch_configuration.squid_nlb.name}"

   tag {
    key                 = "Name"
    value               = "${var.env_nlb_name}_autoscaling_grp_member"
    propagate_at_launch = true
  }
}

#resource "aws_autoscaling_attachment" "squid_nlb" {
#  autoscaling_group_name = "${aws_autoscaling_group.squid_nlb.id}"
#  target_group_arns = ["${aws_lb_target_group.squid_nlb.arn}"]
# }


data "aws_ami" "public_squid_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu16-squid-1.0.2-*"]
  }

  owners = ["${var.ami_account_id}"]
}





# Security groups for the CSOC squid proxy

resource "aws_security_group" "squidnlb_in" {
  name        = "${var.env_nlb_name}-squidnlb_in"
  description = "security group that only enables ssh from VPC nodes and CSOC"
  vpc_id      = "${var.env_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${var.csoc_cidr}"]
  }

  tags {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Service"
  }

  ingress {
    from_port   = 3128
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["${var.csoc_cidr}"]
  }

  tags {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Service"
  }

  lifecycle {
    ignore_changes = ["description"]
  }
}


resource "aws_security_group" "squidnlb_out" {
  name        = "${var.env_nlb_name}-squidnlb_out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${var.env_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Service"
  }
}





