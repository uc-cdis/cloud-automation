# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.60.0 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.60.0"
  name="${var.vpc_name}"
  cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = []
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  assign_generated_ipv6_cidr_block = true
  enable_nat_gateway = false

  tags = {
    Environment = "${var.vpc_name}"
  }
  vpc_tags {
    Name = "${var.vpc_name}"
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/2.16.0/submodules/web
module "web_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/web"
  vpc_id = "${module.vpc.vpc_id}"
  name = "${var.vpc_name}_web_sg"
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/2.16.0/submodules/ssh
module "ssh_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  vpc_id = "${module.vpc.vpc_id}"
  name = "${var.vpc_name}_ssh_sg"
}

# https://www.andreagrandi.it/2017/08/25/getting-latest-ubuntu-ami-with-terraform/
data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "automation_dev" {
  key_name   = "${var.vpc_name}_automation_dev"
  public_key = "${var.ssh_public_key}"
}

# https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/1.21.0
resource "aws_instance" "cluster" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "1.12.0"

  name                   = "${var.vpc_name}"
  # Note - this number should match the number of eip's setup below
  instance_count         = "${var.instance_count}"

  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.instance_type}"
  key_name               = "${aws_key_pair.automation_dev.key_name}"
  monitoring             = false
  vpc_security_group_ids = ["${module.ssh_sg.this_security_group_id}", "${module.web_sg.this_security_group_id}"]
  subnet_id              = "${module.vpc.public_subnets[count.index % 3]}"
  user_data = <<EOF
#!/bin/bash 

(
  hostnamectl set-hostname 'lab${count.id}'
  mkdir -p -m 0755 /var/lib/gen3
  cd /var/lib/gen3
  git clone https://github.com/uc-cdis/cloud-automation.git 
  cd ./cloud-automation
  if [[ ! -d ./Chef ]]; then
    # until the code gets merged
    git checkout chore/labvm
  fi
  cd ./Chef
  bash ./installClient.sh
  # hopefully chef-client is ready to run now
  cd ./repo
  cd /home/ubuntu
  /bin/rm -rf nodes
  # add -l debug for more verbose logging
  chef-client --local-mode --node-name littlenode --override-runlist 'role[labvm]' -l debug
) 2>&1 | tee /var/log/gen3boot.log
  EOF
  
  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device"]
  }
  tags = {
    Terraform = "true"
    Environment = "${vpc_name}"
  }
}


resource "aws_eip" "ips" {
  count = "${var.instance_count}"
  instance = "${aws_instance.cluster.id[count.index]}"
  vpc      = true
}
