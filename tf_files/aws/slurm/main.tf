
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
  user_data = <<EOF
#!/bin/bash
echo "Hello Terraform!"
EOF
}


module "slurm-controllers" {

  source  = "../modules/aws-autoscaling"

  name    = var.slurm_asgs["controllers"]["asg_name"]
  lc_name = "${var.slurm_asgs["controllers"]["asg_name"]}_launch_configuration"

  image_id                     = data.aws_ami.public_ami.id
  instance_type                = var.slurm_asgs["controllers"]["instance_type"] #var.slurm_controller_instance_type
  security_groups              = var.slurm_asgs["controllers"]["security_groups"]
  associate_public_ip_address  = var.slurm_asgs["controllers"]["public_ip"]
  recreate_asg_when_lc_changes = var.slurm_asgs["controllers"]["recreate_on_lc_changes"]


  user_data_base64 = base64encode(local.user_data)

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
}


module "slurm-workers" {

  source  = "../modules/aws-autoscaling"

  name    = var.slurm_asgs["workers"]["asg_name"]
  lc_name = "${var.slurm_asgs["workers"]["asg_name"]}_launch_configuration"

  image_id                     = data.aws_ami.public_ami.id
  instance_type                = var.slurm_asgs["workers"]["instance_type"] #var.slurm_controller_instance_type
  security_groups              = var.slurm_asgs["workers"]["security_groups"]
  associate_public_ip_address  = var.slurm_asgs["workers"]["public_ip"]
  recreate_asg_when_lc_changes = var.slurm_asgs["workers"]["recreate_on_lc_changes"]


  user_data_base64 = base64encode(local.user_data)

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
}




module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "demodb"

  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t2.large"
  allocated_storage = 5

  name     = "demodb"
  username = "user"
  password = "YourPwdShouldBeLongAndSecure!"
  port     = "3306"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = ["sg-12345678"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
  monitoring_interval = "30"
  monitoring_role_name = "MyRDSMonitoringRole"
  create_monitoring_role = true

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  # DB subnet group
  subnet_ids = ["subnet-12345678", "subnet-87654321"]

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "demodb"

  # Database Deletion Protection
  deletion_protection = true

  parameters = [
    {
      name = "character_set_client"
      value = "utf8"
    },
    {
      name = "character_set_server"
      value = "utf8"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}
