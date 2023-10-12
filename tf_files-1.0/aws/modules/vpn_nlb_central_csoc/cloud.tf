### Logging stuff
resource "aws_cloudwatch_log_group" "vpn_log_group" {
  name              = var.cwl_group_name
  retention_in_days = 1827

  tags = {
    Environment  = var.env_vpn_nlb_name
    Organization = var.organization_name
  }
}

## ----- IAM Setup -------

resource "aws_iam_role" "vpn-nlb_role" {
  name = "${var.env_vpn_nlb_name}_role"
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

resource "aws_iam_instance_profile" "vpn-nlb_role_profile" {
  name = "${var.env_vpn_nlb_name}_vpn-nlb_role_profile"
  role = aws_iam_role.vpn-nlb_role.id
}

resource "aws_iam_policy" "vpn_policy" {
  name        = "${var.env_vpn_nlb_name}_policy"
  description = "Cloud watch and S3 policy"
  policy      = data.aws_iam_policy_document.vpn_policy_document.json
}

resource "aws_iam_policy_attachment" "vpn_policy_attachment" {
  name        = "${var.env_vpn_nlb_name}_policy_attach"
  roles       = [aws_iam_role.vpn-nlb_role.name]
  policy_arn  = aws_iam_policy.vpn_policy.arn
}

#Launching the pubate subnets for the VPN VMs
resource "aws_subnet" "vpn_pub0" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = var.env_vpc_id
  cidr_block        = cidrsubnet("${var.vpn_server_subnet}",3,count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = tomap({"Name" = "${var.env_vpn_nlb_name}_pub_${count.index}", "Organization" = var.organization_name, "Environment" = var.env_vpn_nlb_name})
}

resource "aws_route_table_association" "vpn_nlb0" {
  count          = length(aws_subnet.vpn_pub0.*.id)
  subnet_id      = aws_subnet.vpn_pub0.*.id[count.index]
  route_table_id = var.env_pub_subnet_routetable_id
}

# launching the network load balancer for the VPN VMs
resource "aws_lb" "vpn_nlb" {
  name                             = "${var.env_vpn_nlb_name}-prod"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = aws_subnet.vpn_pub0.*.id
  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true

  tags = {
    Environment  = var.env_vpn_nlb_name
    Organization = var.organization_name
  }
}

# For VPN TCP  traffic
resource "aws_lb_target_group" "vpn_nlb-tcp" {
  name     = "${var.env_vpn_nlb_name}-prod-tcp-tg"
  port     = 1194
  protocol = "TCP"
  vpc_id   = var.env_vpc_id

  tags = {
    Environment  = var.env_vpn_nlb_name
    Organization = var.organization_name
  }
}

resource "aws_lb_listener" "vpn_nlb-tcp" {
  load_balancer_arn = aws_lb.vpn_nlb.arn
  port              = "1194"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.vpn_nlb-tcp.arn
    type             = "forward"
  }
}


# For VPN  QR code  traffic
resource "aws_lb_target_group" "vpn_nlb-qr" {
  name     = "${var.env_vpn_nlb_name}-prod-qr-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.env_vpc_id
}

resource "aws_lb_listener" "vpn_nlb-qr" {
  load_balancer_arn = aws_lb.vpn_nlb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.vpn_nlb-qr.arn
    type             = "forward"
  }
}

# For SSH access to the VPn node
resource "aws_lb_target_group" "vpn_nlb-ssh" {
  name     = "${var.env_vpn_nlb_name}-prod-ssh-tg"
  port     = 22
  protocol = "TCP"
  vpc_id   = var.env_vpc_id

  tags = {
    Environment  = var.env_vpn_nlb_name
    Organization = var.organization_name
  }
}

resource "aws_lb_listener" "vpn_nlb-ssh" {
  load_balancer_arn = aws_lb.vpn_nlb.arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.vpn_nlb-ssh.arn
    type             = "forward"
  }
}

# Auto scaling group for VPN nlb
resource "aws_launch_configuration" "vpn_nlb" {
  name_prefix                 = "${var.env_vpn_nlb_name}_autoscaling_launch_config"
  image_id                    = data.aws_ami.public_vpn_ami.id
  instance_type               = "m5.xlarge"
  security_groups             = [aws_security_group.vpnnlb_in.id, aws_security_group.vpnnlb_out.id]
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.vpn-nlb_role_profile.id
  associate_public_ip_address = true
  depends_on                  = [aws_iam_instance_profile.vpn-nlb_role_profile]
  user_data                   = <<EOF
#!/bin/bash

USER="ubuntu"
USER_HOME="/home/$USER"
CLOUD_AUTOMATION="$USER_HOME/cloud-automation"

(
  cd $USER_HOME
  git clone https://github.com/uc-cdis/cloud-automation.git

  # This is needed temporarily for testing purposes ; before merging the code to master
  if [ "${var.branch}" != "master" ];
  then
    cd $CLOUD_AUTOMATION
    git checkout "${var.branch}"
    git pull
  fi


  cat $CLOUD_AUTOMATION/${var.authorized_keys} | sudo tee --append $USER_HOME/.ssh/authorized_keys
  echo "127.0.1.1 ${var.env_vpn_nlb_name}" | sudo tee --append /etc/hosts
  #hostnamectl set-hostname ${var.env_vpn_nlb_name}
  echo ${var.env_cloud_name} | tee /etc/hostname
  hostnamectl set-hostname ${var.env_cloud_name}

  apt -y update
  DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade

  cd $USER_HOME

  bash "${var.bootstrap_path}${var.bootstrap_script}" "cwl_group=${aws_cloudwatch_log_group.vpn_log_group.name};vpn_nlb_name=${var.env_vpn_nlb_name};account_id=${data.aws_caller_identity.current.account_id};csoc_vpn_subnet=${var.csoc_vpn_subnet};csoc_vm_subnet=${var.csoc_vm_subnet};cloud_name=${var.env_cloud_name};${join(";",var.extra_vars)}" 2>&1

  apt autoremove -y
  apt clean
  apt autoclean

  cd $CLOUD_AUTOMATION
  git checkout master
  chown -R $USER. $USER_HOME
) > /var/log/bootstrapping_script.log

EOF

root_block_device {
  volume_size = 30
}  

lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "vpn_nlb" {
  name                 = "${var.env_vpn_nlb_name}_autoscaling_grp"
  desired_capacity     = 1
  max_size             = 1
  min_size             = 1
  target_group_arns    = [aws_lb_target_group.vpn_nlb-tcp.arn,aws_lb_target_group.vpn_nlb-qr.arn,aws_lb_target_group.vpn_nlb-ssh.arn]
  vpc_zone_identifier  = aws_subnet.vpn_pub0.*.id
  launch_configuration = aws_launch_configuration.vpn_nlb.name

  tag {
    key                 = "Name"
    value               = "${var.env_vpn_nlb_name}_autoscaling_grp_member"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.env_vpn_nlb_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Organization"
    value               = var.organization_name
    propagate_at_launch = true
  }
}

# Security groups for the CSOC  VPN VM 
resource "aws_security_group" "vpnnlb_in" {
  name        = "${var.env_vpn_nlb_name}-vpnnlb_in"
  description = "security group that only enables ssh from VPC nodes and CSOC"
  vpc_id      = var.env_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [description]
  }

  tags = {
    Environment  = var.env_vpn_nlb_name
    Organization = var.organization_name
  }
}

resource "aws_security_group" "vpnnlb_out" {
  name        = "${var.env_vpn_nlb_name}-vpnnlb_out"
  description = "security group that allow outbound traffics"
  vpc_id      = var.env_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.env_vpn_nlb_name
    Organization = var.organization_name
  }
}

# DNS entry for the CSOC VPN NLB
resource "aws_route53_record" "vpn-nlb" {
  zone_id = var.csoc_planx_dns_zone_id
  name    = var.env_vpn_nlb_name
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.vpn_nlb.dns_name]
}

resource "aws_s3_bucket" "vpn-certs-and-files" {
  bucket = "vpn-certs-and-files-${var.env_vpn_nlb_name}"

  tags = {
    Name        = "vpn-certs-and-files-${var.env_vpn_nlb_name}"
    Environment = var.env_vpn_nlb_name
    Purpose     = "data bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpn-certs-and-files" {
  bucket = aws_s3_bucket.vpn-certs-and-files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "vpn-certs-and-files" {
  bucket = aws_s3_bucket.vpn-certs-and-files.id

  versioning_configuration {
    status = "Enabled"
  }
}
