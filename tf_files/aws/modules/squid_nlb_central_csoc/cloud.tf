### Logging stuff

resource "aws_cloudwatch_log_group" "squid-nlb_log_group" {
  name              = "${var.env_nlb_name}_log_group"
  retention_in_days = 1827

  tags = {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Services"
  }
}

## ----- IAM Setup -------


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

# These squid VMs should only have access to Cloudwatch and nothing more

data "aws_iam_policy_document" "squid_policy_document" {
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

resource "aws_iam_role_policy" "squid_policy" {
  name   = "${var.env_nlb_name}_policy"
  policy = "${data.aws_iam_policy_document.squid_policy_document.json}"
  role   = "${aws_iam_role.squid-nlb_role.id}"
}

resource "aws_iam_instance_profile" "squid-nlb_role_profile" {
  name = "${var.env_nlb_name}_squid-nlb_role_profile"
  role = "${aws_iam_role.squid-nlb_role.id}"
}




#Launching the private subnets for the squid VMs

data "aws_availability_zones" "available" {}


resource "aws_subnet" "squid_pub0" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.0/27"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_pub0", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_pub1" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.32/27"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_pub1", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_pub2" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.64/27"
  availability_zone = "${data.aws_availability_zones.available.names[2]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_pub2", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_pub3" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.96/27"
  availability_zone = "${data.aws_availability_zones.available.names[3]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_pub3", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_pub4" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.128/27"
  availability_zone = "${data.aws_availability_zones.available.names[4]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_pub4", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}

resource "aws_subnet" "squid_pub5" {
  vpc_id                  = "${var.env_vpc_id}"
  cidr_block              = "10.128.${var.env_vpc_octet3}.160/27"
  availability_zone = "${data.aws_availability_zones.available.names[5]}"
  tags                    = "${map("Name", "${var.env_nlb_name}_pub5", "Organization", "Basic Service", "Environment", var.env_nlb_name)}"
}





resource "aws_route_table_association" "squid_nlb0" {
  subnet_id      = "${aws_subnet.squid_pub0.id}"
  route_table_id = "${var.env_pub_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb1" {
  subnet_id      = "${aws_subnet.squid_pub1.id}"
  route_table_id = "${var.env_pub_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb2" {
  subnet_id      = "${aws_subnet.squid_pub2.id}"
  route_table_id = "${var.env_pub_subnet_routetable_id}"
}


resource "aws_route_table_association" "squid_nlb3" {
  subnet_id      = "${aws_subnet.squid_pub3.id}"
  route_table_id = "${var.env_pub_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb4" {
  subnet_id      = "${aws_subnet.squid_pub4.id}"
  route_table_id = "${var.env_pub_subnet_routetable_id}"
}

resource "aws_route_table_association" "squid_nlb5" {
  subnet_id      = "${aws_subnet.squid_pub5.id}"
  route_table_id = "${var.env_pub_subnet_routetable_id}"
}




# launching the network load balancer for the squid VMs

resource "aws_lb" "squid_nlb" {
  name               = "${var.env_nlb_name}-prod"
  internal           = true
  load_balancer_type = "network"
    subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_pub0.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_pub1.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_pub2.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_pub3.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_pub4.id}"
  }
   subnet_mapping {
       subnet_id    =  "${aws_subnet.squid_pub5.id}"
  }


  
   

  enable_deletion_protection = true
  enable_cross_zone_load_balancing = true

  tags = {
    Environment = "production"
  }
  lifecycle{ignore_changes=["subnet_mapping"]}
}
# For http/https traffic
resource "aws_lb_target_group" "squid_nlb-http" {
  name     = "${var.env_nlb_name}-prod-http-tg"
  port     = 3128
  protocol = "TCP"
  vpc_id   = "${var.env_vpc_id}"
  proxy_protocol_v2 = "True"
  }

resource "aws_lb_listener" "squid_nlb-http" {
  load_balancer_arn = "${aws_lb.squid_nlb.arn}"
  port              = "3128"
  protocol          = "TCP"
  default_action {
    target_group_arn = "${aws_lb_target_group.squid_nlb-http.arn}"
    type             = "forward"
  }
}

# For  SFTP traffic

resource "aws_lb_target_group" "squid_nlb-sftp" {
  name     = "${var.env_nlb_name}-prod-sftp-tg"
  port     = 22
  protocol = "TCP"
  vpc_id   = "${var.env_vpc_id}"
}

resource "aws_lb_listener" "squid_nlb-sftp" {
  load_balancer_arn = "${aws_lb.squid_nlb.arn}"
  port              = "22"
  protocol          = "TCP"
  default_action {
    target_group_arn = "${aws_lb_target_group.squid_nlb-sftp.arn}"
    type             = "forward"
  }
}


## Endpoint service for squid nlb

resource "aws_vpc_endpoint_service" "squid_nlb" {
  acceptance_required =  false
  network_load_balancer_arns = ["${aws_lb.squid_nlb.arn}"]
  #availability_zones = ["us-east-1a","us-east-1b","us-east-1c","us-east-1d","us-east-1e","us-east-1f"]
  allowed_principals = "${var.allowed_principals_list}"
}



# Auto scaling group for squid nlb

resource "aws_launch_configuration" "squid_nlb" {
  name_prefix = "${var.env_nlb_name}_autoscaling_launch_config"
  image_id = "${data.aws_ami.public_squid_ami.id}"
  #instance_type = "t2.medium"
  instance_type = "t3.xlarge"
  security_groups = ["${aws_security_group.squidnlb_in.id}", "${aws_security_group.squidnlb_out.id}"]
  key_name = "${var.ssh_key_name}"
  iam_instance_profile   = "${aws_iam_instance_profile.squid-nlb_role_profile.id}"
  associate_public_ip_address = true
  root_block_device {
    volume_size = 30
  }

  depends_on = ["aws_iam_instance_profile.squid-nlb_role_profile"]

user_data = <<EOF
#!/bin/bash
cd /home/ubuntu
sudo git clone https://github.com/uc-cdis/cloud-automation.git
sudo chown -R ubuntu. /home/ubuntu/cloud-automation
cd /home/ubuntu/cloud-automation
git pull
# this is just temporary to test stuff from my branch; not needed once it is merged
#git checkout fix/squidnlbloggingfixv1
#git pull
#####
sudo chown -R ubuntu. /home/ubuntu/cloud-automation

echo "127.0.1.1 ${var.env_nlb_name}" | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname ${var.env_nlb_name}

sudo apt -y update
sudo DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade| sudo tee --append /var/log/bootstrapping_script.log

sudo apt-get autoremove -y
sudo apt-get clean
sudo apt-get autoclean

cd /home/ubuntu
sudo bash "${var.bootstrap_path}${var.bootstrap_script}" 2>&1 |sudo tee --append /var/log/bootstrapping_script.log
EOF

lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "squid_nlb" {
  name = "${var.env_nlb_name}_autoscaling_grp"
#If you define a list of subnet IDs split across the desired availability zones set them using vpc_zone_identifier 
# and there is no need to set availability_zones.
# (https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#availability_zones).


  desired_capacity = 3
  max_size = 6
  min_size = 1
  target_group_arns = ["${aws_lb_target_group.squid_nlb-http.arn}", "${aws_lb_target_group.squid_nlb-sftp.arn}"]
  vpc_zone_identifier = ["${aws_subnet.squid_pub0.id}", "${aws_subnet.squid_pub1.id}", "${aws_subnet.squid_pub2.id}", "${aws_subnet.squid_pub3.id}", "${aws_subnet.squid_pub4.id}", "${aws_subnet.squid_pub5.id}"]
  launch_configuration = "${aws_launch_configuration.squid_nlb.name}"

   tag {
    key                 = "Name"
    value               = "${var.env_nlb_name}_autoscaling_grp_member"
    propagate_at_launch = true
  }
}




data "aws_ami" "public_squid_ami" {
  most_recent = true

  filter {
    name   = "name"
    #values = ["ubuntu16-squid-1.0.2-*"]
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

  tags = {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Service"
  }

  ingress {
    from_port   = 3128
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["${var.csoc_cidr}"]
  }

  tags = {
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

  tags = {
    Environment  = "${var.env_nlb_name}"
    Organization = "Basic Service"
  }
}


# DNS entry for the cloud-proxy in CSOC

resource "aws_route53_record" "squid-nlb" {
  zone_id = "${var.csoc_internal_dns_zone_id}"
  name    = "cloud-proxy.internal.io"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_lb.squid_nlb.dns_name}"]
}





