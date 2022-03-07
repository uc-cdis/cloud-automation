provider "aws" {
  #version = "4.4.0"
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

data "aws_ami" "eksoptimized" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amazon-eks-node-1.21-*"]
  }
}

output "fetched_AMI_Id" {
  value = data.aws_ami.eksoptimized.image_id
}

resource "aws_imagebuilder_image_recipe" "recipe01" {
  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 35
      volume_type           = "gp2"
      #encrypted = true
      #kms_key_id = "alias/test-ajo-01"
    }
  }
  component {
    component_arn = "arn:aws:imagebuilder:us-east-1:aws:component/aws-cli-version-2-linux/x.x.x"
  }
  user_data_base64 = "${base64encode(local.eks-instance-userdata)}"
  name         = "recipe-tf-01"
  description  = "Image Recipe for EKS Optimized AMI v1.21.x"
  parent_image = data.aws_ami.eksoptimized.image_id
  version      = "5.0.0"
  working_directory = "/tmp"
}

resource "aws_imagebuilder_infrastructure_configuration" "configuration_generic" {
  name = "infrastructure-configuration-generic-01"
  instance_profile_name = "EC2InstanceProfileForImageBuilder"
}
resource "aws_imagebuilder_distribution_configuration" "distribution_configuration_generic" {
  name = "distribution settings generic 01"
  distribution {
    region = "us-east-1"
    ami_distribution_configuration {
      launch_permission {
        user_ids = ["433568766270"]
        #user_groups = "private"
      }
    }
  }
}

resource "aws_imagebuilder_image_pipeline" "image_pipeline_generic" {
  name             = "Image-Pipeline-EKS-V1-21"
  image_recipe_arn = aws_imagebuilder_image_recipe.recipe01.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.configuration_generic.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.distribution_configuration_generic.arn
  schedule {
    schedule_expression = "cron(0 0 ? * 2 *)"
  }
}














