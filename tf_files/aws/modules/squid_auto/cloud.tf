locals{
  cidrs  = "${split(",", var.secondary_cidr_block != "" ? join(",", list(var.env_vpc_cidr, var.peering_cidr, var.secondary_cidr_block)) : join(",", list(var.env_vpc_cidr, var.peering_cidr)))}"
  cidrs2 = "${split(",", var.secondary_cidr_block != "" ? join(",", list(var.env_vpc_cidr, var.secondary_cidr_block)) : join(",", list(var.env_vpc_cidr)))}"
}

#Launching the public subnets for the squid VMs
# If squid is launched in PROD 172.X.Y+5.0/24 subnet is used; For QA/DEV 172.X.Y+1.0/24 subnet is used
# The value of var.environment is supplied as a user variable - 1 for PROD and 0 for QA/DEV

# FOR PROD ENVIRONMENT:

resource "aws_subnet" "squid_pub0" {
  count                   = "${var.deploy_ha_squid ? length(var.squid_availability_zones) : 0}"
  vpc_id                  = "${var.env_vpc_id}"
  #cidr_block              = "${cidrsubnet(var.squid_proxy_subnet,3,count.index )}"
  cidr_block              = "${var.network_expansion ? cidrsubnet(var.squid_proxy_subnet,2,count.index) : cidrsubnet(var.squid_proxy_subnet,3,count.index )}"
  availability_zone       = "${var.squid_availability_zones[count.index]}"
  tags                    = "${map("Name", "${var.env_squid_name}_pub${count.index}", "Organization", var.organization_name, "Environment", var.env_squid_name)}"
}



# Instance profile role and policies, we need the proxy to be able to talk to cloudwatchlogs groups
#
##########################
resource "aws_iam_role" "squid-auto_role" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
  name  = "${var.env_squid_name}_role"
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


resource "aws_iam_role_policy" "squid_policy" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
  name   = "${var.env_squid_name}_policy"
  policy = "${data.aws_iam_policy_document.squid_policy_document.json}"
  role   = "${aws_iam_role.squid-auto_role.id}"
}

# Amazon SSM Policy
resource "aws_iam_role_policy_attachment" "eks-policy-AmazonSSMManagedInstanceCore" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role   = "${aws_iam_role.squid-auto_role.id}"
}

resource "aws_iam_instance_profile" "squid-auto_role_profile" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
  name = "${var.env_vpc_name}_squid-auto_role_profile"
  role = "${aws_iam_role.squid-auto_role.id}"
}

data "aws_iam_policy_document" "squid_policy_document" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
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
  statement {
    actions = [
      "s3:Get*",
      "s3:List*"
    ]
    effect    = "Allow"
    resources = ["arn:aws:s3:::qualys-agentpackage", "arn:aws:s3:::qualys-agentpackage/*"]
  }
}

##################


resource "aws_route_table_association" "squid_auto0" {
  #count          = "${length(var.squid_availability_zones)}"
  count          = "${var.deploy_ha_squid ? length(var.squid_availability_zones) : 0}"
  subnet_id      = "${aws_subnet.squid_pub0.*.id[count.index]}"
  route_table_id = "${var.main_public_route}"
}


# Auto scaling group for squid auto

resource "aws_launch_configuration" "squid_auto" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
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
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
USER="ubuntu"
if [[ $DISTRO == "Amazon Linux" ]]; then
  USER="ec2-user"
fi
USER_HOME="/home/$USER"
CLOUD_AUTOMATION="$USER_HOME/cloud-automation"
(
  cd $USER_HOME
  if [[ ! -z "${var.slack_webhook}" ]]; then
    echo "${var.slack_webhook}" > /slackWebhook
  fi
  if [[ $DISTRO == "Amazon Linux" ]]; then
    sudo yum update -y
    sudo yum install git lsof -y
  fi
  git clone https://github.com/uc-cdis/cloud-automation.git
  cd $CLOUD_AUTOMATION
  git pull

  # This is needed temporarily for testing purposes ; before merging the code to master
  if [ "${var.branch}" != "master" ];
  then
    git checkout "${var.branch}"
    git pull
  fi
  chown -R $USER. $CLOUD_AUTOMATION

  echo "127.0.1.1 ${var.env_squid_name}" | tee --append /etc/hosts
  hostnamectl set-hostname ${var.env_squid_name}
  if [[ $DISTRO == "Ubuntu" ]]; then
    apt -y update
    DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade

    apt autoremove -y
    apt clean
    apt autoclean
  fi
  cd $USER_HOME

  bash "${var.bootstrap_path}${var.bootstrap_script}" "cwl_group=${var.env_log_group};${join(";",var.extra_vars)}" 2>&1
  cd $CLOUD_AUTOMATION
  git checkout master
  # Install qualys agent if the activtion and customer id provided
  # Amazon Linux does not support qualys agent (?)
  # https://success.qualys.com/discussions/s/question/0D52L00004TnwvgSAB/installing-qualys-cloud-agent-on-amazon-linux-2-instances
  if [[ $DISTRO == "Ubuntu" ]]; then
    if [[ ! -z "${var.activation_id}" ]] || [[ ! -z "${var.customer_id}" ]]; then
      apt install awscli jq -y
      aws s3 cp s3://qualys-agentpackage/QualysCloudAgent.deb ./qualys-cloud-agent.x86_64.deb
      dpkg -i ./qualys-cloud-agent.x86_64.deb
      # Clean up deb package after install
      rm qualys-cloud-agent.x86_64.deb
      sudo /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=${var.activation_id} CustomerId=${var.customer_id}
    fi
  fi
) > /var/log/bootstrapping_script.log
EOF

lifecycle {
    create_before_destroy = true
  }
  depends_on = ["aws_iam_instance_profile.squid-auto_role_profile"]

}

resource "null_resource" "service_depends_on" {
  triggers = {
    # This reference creates an implicit dependency on the variable, and thus
    # transitively on everything the variable itself depends on.
    deps = "${jsonencode(var.squid_depends_on)}"
  }
}

# Create a new iam service linked role that we can grant access to KMS keys in other accounts
# Needed if we need to bring up custom AMI's that have been encrypted using a kms key
resource "aws_iam_service_linked_role" "squidautoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  custom_suffix = "${var.env_vpc_name}_squid"
  lifecycle {
    ignore_changes = ["custom_suffix"]
  }
}

# Remember to grant access to the account in the KMS key policy too
resource "aws_kms_grant" "kms" {
  count = "${var.fips ? 1 : 0}"
  name              = "kms-cmk-eks"
  key_id            = "${var.fips_ami_kms}"
  grantee_principal = "${aws_iam_service_linked_role.squidautoscaling.arn}"
  operations        = ["Encrypt", "Decrypt", "ReEncryptFrom", "ReEncryptTo", "GenerateDataKey", "GenerateDataKeyWithoutPlaintext", "DescribeKey", "CreateGrant"]
}

resource "aws_autoscaling_group" "squid_auto" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
  name = "${var.env_squid_name}"
  service_linked_role_arn = "${aws_iam_service_linked_role.squidautoscaling.arn}"
  desired_capacity = "${var.cluster_desired_capasity}"
  max_size = "${var.cluster_max_size}"
  min_size = "${var.cluster_min_size}"
  vpc_zone_identifier = ["${aws_subnet.squid_pub0.*.id}"]
  launch_configuration = "${aws_launch_configuration.squid_auto.name}"
  depends_on           = ["null_resource.service_depends_on", "aws_route_table_association.squid_auto0"]
  tag {
    key                 = "Name"
    value               = "${var.env_squid_name}-grp-member"
    propagate_at_launch = true
  }
  tag {
    key   = "Environment"
    value = "${var.organization_name}"
    propagate_at_launch = true
  }

}


# Security groups for the Commons squid proxy

resource "aws_security_group" "squidauto_in" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
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
    cidr_blocks  = ["${local.cidrs}"]
  }

  tags = {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }

  ingress {
    from_port   = 3128
    to_port     = 3128
    protocol    = "TCP"
    cidr_blocks  = ["${local.cidrs}"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks  = ["${local.cidrs2}"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks  = ["${local.cidrs2}"]
  }

  lifecycle {
    ignore_changes = ["description"]
  }
}


resource "aws_security_group" "squidauto_out" {
  count = "${var.deploy_ha_squid ? 1 : 0}"
  name        = "${var.env_squid_name}-squidauto_out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${var.env_vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${var.env_squid_name}"
    Organization = "${var.organization_name}"
  }
}
