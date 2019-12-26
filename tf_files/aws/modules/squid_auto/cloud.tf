

#Launching the public subnets for the squid VMs
# If squid is launched in PROD 172.X.Y+5.0/24 subnet is used; For QA/DEV 172.X.Y+1.0/24 subnet is used
# The value of var.environment is supplied as a user variable - 1 for PROD and 0 for QA/DEV

# FOR PROD ENVIRONMENT:

resource "aws_subnet" "squid_pub0" {
  count                   = "${length(var.squid_availability_zones)}"
  vpc_id                  = "${var.env_vpc_id}"
  #cidr_block              = "${cidrsubnet("${var.squid_proxy_subnet}",3,count.index )}"
  cidr_block              = "${cidrsubnet(var.squid_proxy_subnet,3,count.index )}"
  availability_zone       = "${var.squid_availability_zones[count.index]}"
  tags                    = "${map("Name", "${var.env_squid_name}_pub${count.index}", "Organization", var.organization_name, "Environment", var.env_squid_name)}"
}



# Instance profile role and policies, we need the proxy to be able to talk to cloudwatchlogs groups 
#
##########################
resource "aws_iam_role" "squid-auto_role" {
  name = "${var.env_squid_name}_role"
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


resource "aws_iam_role_policy" "squid_policy" {
  name   = "${var.env_squid_name}_policy"
  policy = "${data.aws_iam_policy_document.squid_policy_document.json}"
  role   = "${aws_iam_role.squid-auto_role.id}"
}


resource "aws_iam_instance_profile" "squid-auto_role_profile" {
  name = "${var.env_vpc_name}_squid-auto_role_profile"
  role = "${aws_iam_role.squid-auto_role.id}"
}

data "aws_iam_policy_document" "squid_policy_document" {
  statement {
    actions = [
      "ec2:*",
      "route53:*",
      "autoscaling:*",
      "sts:AssumeRole",
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

##################


resource "aws_route_table_association" "squid_auto0" {
  count          = "${length(var.squid_availability_zones)}"
  subnet_id      = "${aws_subnet.squid_pub0.*.id[count.index]}"
#  route_table_id = "${data.aws_route_table.public_route_table.id}"
  route_table_id = "${var.main_public_route}"
}


# Auto scaling group for squid auto

resource "aws_launch_configuration" "squid_auto" {
  name_prefix                 = "${var.env_squid_name}_autoscaling_launch_config"
  image_id                    = "${data.aws_ami.public_squid_ami.id}"
  instance_type               = "${var.squid_instance_type}"
  security_groups             = ["${aws_security_group.squidauto_in.id}", "${aws_security_group.squidauto_out.id}"]
  key_name                    = "${var.ssh_key_name}"
  iam_instance_profile        = "${aws_iam_instance_profile.squid-auto_role_profile.id}"
  associate_public_ip_address = true
  root_block_device {
    volume_size = "${var.squid_instance_drive_size}"
  }



user_data = <<EOF
#!/bin/bash
cd /home/ubuntu
git clone https://github.com/uc-cdis/cloud-automation.git
chown -R ubuntu. /home/ubuntu/cloud-automation
cd /home/ubuntu/cloud-automation
git pull

# This is needed temporarily for testing purposes ; before merging the code to master
git checkout feat/ha-squid
git pull

sudo chown -R ubuntu. /home/ubuntu/cloud-automation

#instance_ip=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
echo "127.0.1.1 ${var.env_squid_name}" | tee --append /etc/hosts
hostnamectl set-hostname ${var.env_squid_name}

apt -y update
DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade| sudo tee --append /var/log/bootstrapping_script.log

apt-get autoremove -y
apt-get clean
apt-get autoclean

cd /home/ubuntu

cp /home/ubuntu/cloud-automation/flavors/squid_auto/proxy_route53_config.sh /home/ubuntu/
cp /home/ubuntu/cloud-automation/flavors/squid_auto/default_ip_route_and_instance_check_config.sh /home/ubuntu/
cp /home/ubuntu/cloud-automation/flavors/squid_auto/squid_auto_user_variable /home/ubuntu/


# Replace the User variable for hostname, VPN subnet and VM subnet 

sed -i "s/DNS_ZONE_ID/${var.route_53_zone_id}/" /home/ubuntu/squid_auto_user_variable
sed -i "s/PRIVATE_KUBE_ROUTETABLE_ID/${var.private_kube_route}/" /home/ubuntu/squid_auto_user_variable
sed -i "s/COMMONS_SQUID_ROLE/${var.env_squid_name}/" /home/ubuntu/squid_auto_user_variable

#####
bash "${var.bootstrap_path}${var.bootstrap_script}" cwl_group="${var.env_log_group}" 2>&1 |tee --append /var/log/bootstrapping_script.log
EOF
#sed -i "s/PRIVATE_KUBE_ROUTETABLE_ID/${data.aws_route_table.private_kube_route_table.id}/" /home/ubuntu/squid_auto_user_variable
#sed -i "s/DNS_ZONE_ID/${data.aws_route53_zone.vpczone.zone_id}/" /home/ubuntu/squid_auto_user_variable

lifecycle {
    create_before_destroy = true
  }
  depends_on = ["aws_iam_instance_profile.squid-auto_role_profile"]

}

resource "aws_autoscaling_group" "squid_auto" {
  name = "${var.env_squid_name}"
#If you define a list of subnet IDs split across the desired availability zones set them using vpc_zone_identifier 
# and there is no need to set availability_zones.
# (https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#availability_zones).
  desired_capacity = 2
  max_size = 3
  min_size = 1
  vpc_zone_identifier = ["${aws_subnet.squid_pub0.*.id}"] 
  launch_configuration = "${aws_launch_configuration.squid_auto.name}"

   tag {
    key                 = "Name"
    value               = "${var.env_squid_name}-grp-member"
    propagate_at_launch = true
  }
}




data "aws_ami" "public_squid_ami" {
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





# Security groups for the Commons squid proxy

resource "aws_security_group" "squidauto_in" {
  name        = "${var.env_squid_name}-squidauto_in"
  description = "security group that only enables ssh from VPC nodes and CSOC"
  vpc_id      = "${var.env_vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    #
    # Do not do this - fence may ssh-bridge out for sftp access
    #
    cidr_blocks = ["${var.csoc_cidr}", "${var.env_vpc_cidr}"]
  }

  tags {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }

  ingress {
    from_port   = 3128
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}"]
  }

  tags {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}"]
  }

  tags {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["${var.env_vpc_cidr}"]
  }

  tags {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }

  lifecycle {
    ignore_changes = ["description"]
  }
}


resource "aws_security_group" "squidauto_out" {
  name        = "${var.env_squid_name}-squidauto_out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${var.env_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }
}

