provider "aws" {
  version = "4.4.0"
}

locals {
eks-instance-userdata = <<EOF
#!/bin/bash
# update yum repo
sudo yum update -y
# install and enable FIPS modules
sudo yum install -y dracut-fips openssl >> /opt/fips-install.log
sudo  dracut -f
# configure grub
sudo /sbin/grubby --update-kernel=ALL --args="fips=1"
EOF
}

resource "aws_imagebuilder_image_recipe" "recipe" {
  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 35
      volume_type           = "gp2"
    }
  }
  component {
    component_arn = "arn:aws:imagebuilder:us-east-1:aws:component/aws-cli-version-2-linux/x.x.x"
  }
  user_data_base64 = "${base64encode(local.eks-instance-userdata)}"
  name         = "recipe-EKS-image-${var.base_image}"
  description  = "Image Recipe for EKS Optimized AMI"
  parent_image = data.aws_ami.eksoptimized.image_id
  version      = "1.0.0"
  working_directory = "/tmp"
}

resource "aws_imagebuilder_infrastructure_configuration" "configuration" {
  name = "infrastructure-configuration-version-${var.image_version}"
  instance_profile_name = "EC2InstanceProfileForImageBuilder"
}

resource "aws_imagebuilder_distribution_configuration" "distribution_configuration" {
  name = "distribution settings for version ${var.image_version}"
  distribution {
    region = "us-east-1"
    ami_distribution_configuration {
      launch_permission {
        user_ids = ["${var.account_id}"]
        #user_groups = "private"
      }
    }
  }
}

resource "aws_imagebuilder_image_pipeline" "image_pipeline_generic" {
  name             = "Image-Pipeline-EKS-V${var.image_version}"
  image_recipe_arn = aws_imagebuilder_image_recipe.recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.configuration.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.distribution_configuration.arn
  schedule {
    schedule_expression = "${var.cron_schedule}"
  }
}














