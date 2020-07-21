
# Inject credentials via the AWS_PROFILE environment variable and shared credentials file
# and/or EC2 metadata service
terraform {
  backend "s3" {
    encrypt = "true"
  }

  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.41"
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
#  version = "~> 3.0"

  name    = var.slurm_controllers_asg_name
  lc_name = "${var.slurm_controllers_asg_name}_launch_configuration"

  image_id                     = data.aws_ami.public_ami.id
  instance_type                = var.slurm_controller_instance_type
#  security_groups              = [data.aws_security_group.default.id]
  security_groups              = var.slurm_controller_sec_group
  associate_public_ip_address  = var.slurm_controller_associate_public_ip
  recreate_asg_when_lc_changes = var.slurm_controller_recreate_when_lc_changes


  user_data_base64 = base64encode(local.user_data)

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size           = "50"
      volume_type           = "gp2"
      delete_on_termination = true
    },
  ]

  # Auto scaling group
#  asg_name                  = "example-asg"
  asg_name                  = var.slurm_controllers_asg_name
#  vpc_zone_identifier       = data.aws_subnet_ids.all.ids
  vpc_zone_identifier       = var.slurm_controller_subnet_id
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 0
  wait_for_capacity_timeout = 0
#  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Project"
      value               = "megasecret"
      propagate_at_launch = true
    },
  ]

  tags_as_map = {
    extra_tag1 = "extra_value1"
    extra_tag2 = "extra_value2"
  }
}
