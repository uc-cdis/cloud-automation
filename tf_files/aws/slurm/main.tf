
# Inject credentials via the AWS_PROFILE environment variable and shared credentials file
# and/or EC2 metadata service
terraform {
  backend "s3" {
    encrypt = "true"
  }

  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.41"
    null = "~> 2.1"
    random = "~>2.3"
  }
}

# Inject credentials via the AWS_PROFILE environment variable and shared credentials file and/or EC2 metadata service
#
provider "aws" {
  region = var.slurm_cluster_region
}


locals {
  user_common_data = <<EOF
#!/bin/bash

cat > /etc/environment  <<ENVPROXY
http_proxy=http://cloud-proxy.internal.io:3128
https_proxy=http://cloud-proxy.internal.io:3128
no_proxy=localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com
ENVPROXY

cat > /etc/apt/apt.conf.d/01proxy <<APTPROXY
Acquire::http::Proxy "http://cloud-proxy.internal.io:3128";
Acquire::https::Proxy "http://cloud-proxy.internal.io:3128";
APTPROXY

cat > /etc/profile.d/99-proxy.sh <<PROFILEPROXY
#!/bin/bash
export http{,s}_proxy=http://cloud-proxy.internal.io:3128
export no_proxy="localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.${data.aws_region.current.name}.amazonaws.com"
PROFILEPROXY

chmod +x /etc/profile.d/99-proxy.sh

USER="${var.main_os_user}"
USER_HOME="/home/$USER"
CLOUD_AUTOMATION="$USER_HOME/cloud-automation"

source /etc/profile.d/99-proxy.sh
cd $USER_HOME
git clone https://github.com/uc-cdis/cloud-automation.git
cd $CLOUD_AUTOMATION
git pull

# In case we want test branches while deploying
if [ "${var.branch}" != "master" ];
then
  git checkout "${var.branch}"
  git pull
fi
cat $CLOUD_AUTOMATION/${var.authorized_keys} | sudo tee --append $USER_HOME/.ssh/authorized_keys
chown -R ubuntu. $CLOUD_AUTOMATION

apt -y update
DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade

apt autoremove -y
apt clean
apt autoclean

EOF

  user_controller_data = <<EOF

(
  cd $USER_HOME

#  bash "${var.controller_info["bootstrap_script"]}" "cwl_group=${var.cwlg_name};${var.controller_info["extra_vars"]}" 2>&1
  cd $CLOUD_AUTOMATION
  git checkout master
) > /var/log/bootstrapping_script.log

EOF

  user_workers_data = <<EOF

(
  cd $USER_HOME

#  bash "${var.worker_info["bootstrap_script"]}" "cwl_group=${var.cwlg_name};;${var.worker_info["extra_vars"]}" 2>&1
  cd $CLOUD_AUTOMATION
  git checkout master
) > /var/log/bootstrapping_script.log
EOF
  
}


resource "aws_iam_role" "the_role" {
  name                  = "${var.vpc_name}_slurm_instances_role"
  description           = "Role for slurm instances"
  force_detach_policies = true

  assume_role_policy    =  <<EOF
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

  tags                  =  {
    Environment  = var.vpc_name
    Organization = var.organization_name
  }
}



resource "aws_iam_role_policy" "slurm_instances_role" {
  name                  = "basicAccess"
  policy                = data.aws_iam_policy_document.vm_policy_document.json
  role                  = aws_iam_role.the_role.id
}

resource "aws_iam_role_policy" "slurm_access_to_data_bucket" {
  count  = length(data.aws_iam_policy_document.source_bucket_acccess)
  name   = "access_to_data_buckets_${count.index}"
  policy = data.aws_iam_policy_document.source_bucket_acccess[count.index].json
  ### element(data.aws_iam_policy_document.source_bucket_acccess, count.index)
  role   = aws_iam_role.the_role.id
}

resource "aws_iam_role_policy" "slurm_access_to_output_bucket" {
  name   = "access_to_output_bucket"
  policy = data.aws_iam_policy_document.output_bucket_access.json
  role   = aws_iam_role.the_role.id
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.the_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_instance_profile" "slurm_nodes_instance_profile" {
  name = "${var.vpc_name}_slurm_instances"
  role = aws_iam_role.the_role.name
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.vpc_name}-slurm-data-bucket"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags  = {
    Name         = "${var.vpc_name}-data-bucket"
    Organization = var.organization_name
    Purpose      = "data bucket"
  }

}


resource "aws_s3_bucket_public_access_block" "data_bucket_privacy" {
  bucket                      = aws_s3_bucket.data_bucket.id

  block_public_acls           = true
  block_public_policy         = true
  ignore_public_acls          = true
  restrict_public_buckets     = true
}

module "slurm-controllers" {

  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name    = var.slurm_asgs["controllers"]["asg_name"]
  lc_name = "${var.slurm_asgs["controllers"]["asg_name"]}_launch_configuration"

  image_id                     = data.aws_ami.public_ami.id
  instance_type                = var.slurm_asgs["controllers"]["instance_type"] #var.slurm_controller_instance_type
  security_groups              = var.slurm_asgs["controllers"]["security_groups"]
  associate_public_ip_address  = var.slurm_asgs["controllers"]["public_ip"]
  recreate_asg_when_lc_changes = var.slurm_asgs["controllers"]["recreate_on_lc_changes"]
  iam_instance_profile         = aws_iam_instance_profile.slurm_nodes_instance_profile.id


#  user_data_base64 = base64encode(local.user_data)
  user_data         = "${local.user_common_data} ${local.user_controller_data}"

  root_block_device = [
    {
      volume_size           = var.slurm_asgs["controllers"]["root_block"]["volume_size"]
      volume_type           = var.slurm_asgs["controllers"]["root_block"]["volume_type"]
      delete_on_termination = var.slurm_asgs["controllers"]["root_block"]["delete_on_termination"]
      encryption            = true
    },
  ]

  # Auto scaling group
  asg_name                  = var.slurm_asgs["controllers"]["asg_name"]
  vpc_zone_identifier       = var.slurm_asgs["controllers"]["subnets_id"]
  health_check_type         = var.slurm_asgs["controllers"]["health_check_type"]
  min_size                  = var.slurm_asgs["controllers"]["min_size"]
  max_size                  = var.slurm_asgs["controllers"]["max_size"]
  desired_capacity          = var.slurm_asgs["controllers"]["desired_capasity"]
  wait_for_capacity_timeout = 0

  tags_as_map = var.slurm_asgs["controllers"]["tags"]

  tags = [
    {
      key   = "slurm-type"
      value = "controller"
      propagate_at_launch = true
    }
  ]
}


module "slurm-workers" {

  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name    = var.slurm_asgs["workers"]["asg_name"]
  lc_name = "${var.slurm_asgs["workers"]["asg_name"]}_launch_configuration"

  image_id                     = data.aws_ami.public_ami.id
  instance_type                = var.slurm_asgs["workers"]["instance_type"] #var.slurm_controller_instance_type
  security_groups              = var.slurm_asgs["workers"]["security_groups"]
  associate_public_ip_address  = var.slurm_asgs["workers"]["public_ip"]
  recreate_asg_when_lc_changes = var.slurm_asgs["workers"]["recreate_on_lc_changes"]
  iam_instance_profile         = aws_iam_instance_profile.slurm_nodes_instance_profile.id


  #user_data_base64 = base64encode(local.user_data)
  #user_data         = local.user_data
  user_data         = "${local.user_common_data} ${local.user_workers_data}"

  root_block_device = [
    {
      volume_size           = var.slurm_asgs["workers"]["root_block"]["volume_size"]
      volume_type           = var.slurm_asgs["workers"]["root_block"]["volume_type"]
      delete_on_termination = var.slurm_asgs["workers"]["root_block"]["delete_on_termination"]
      encryption            = true
    },
  ]

  # Auto scaling group
  asg_name                  = var.slurm_asgs["workers"]["asg_name"]
  vpc_zone_identifier       = var.slurm_asgs["workers"]["subnets_id"]
  health_check_type         = var.slurm_asgs["workers"]["health_check_type"]
  min_size                  = var.slurm_asgs["workers"]["min_size"]
  max_size                  = var.slurm_asgs["workers"]["max_size"]
  desired_capacity          = var.slurm_asgs["workers"]["desired_capasity"]
  wait_for_capacity_timeout = 0

  tags_as_map = var.slurm_asgs["workers"]["tags"]

  tags = [
    {
      key   = "slurm-type"
      value = "worker"
      propagate_at_launch = true
    }
  ]
}




module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier         = var.slurm_rds["slurmdb"]["name"]

  engine             = var.slurm_rds["slurmdb"]["engine"]
  engine_version     = var.slurm_rds["slurmdb"]["engine_version"]
  instance_class     = var.slurm_rds["slurmdb"]["instance_class"]
  allocated_storage  = var.slurm_rds["slurmdb"]["allocated_storage"]

  name               = var.slurm_rds["slurmdb"]["name"]
  username           = var.slurm_rds["slurmdb"]["username"]
  password           = var.slurm_rds["slurmdb"]["password"]
  port               = var.slurm_rds["slurmdb"]["port"]


  maintenance_window = var.slurm_rds["slurmdb"]["maintenance_window"]
  backup_window      = var.slurm_rds["slurmdb"]["backup_window"]
  subnet_ids         = var.slurm_rds["slurmdb"]["subnet_ids"] 


  iam_database_authentication_enabled = var.slurm_rds["slurmdb"]["iam_database_authentication_enabled"]
  vpc_security_group_ids              = var.slurm_rds["slurmdb"]["vpc_security_group_ids"]

  # DB parameter group
  family                              = var.slurm_rds["slurmdb"]["family"]

  # DB option group
  major_engine_version                = var.slurm_rds["slurmdb"]["major_engine_version"]

  # Snapshot name upon DB deletion
  final_snapshot_identifier           = var.slurm_rds["slurmdb"]["final_snapshot_identifier"]

  # Database Deletion Protection
  deletion_protection                 = var.slurm_rds["slurmdb"]["deletion_protection"]

  parameters                          = var.slurm_rds["slurmdb"]["parameters"]
  tags                                = var.slurm_rds["slurmdb"]["tags"]

  # The following is assuming we want this instances in existing subnets groups
  db_subnet_group_name                = var.slurm_rds["slurmdb"]["db_subnet_group_name"]

}
