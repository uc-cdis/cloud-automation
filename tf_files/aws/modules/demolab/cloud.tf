locals {
  # kube-aws does not like '-' in cluster name
  environment = "lab_${var.vpc_name}"
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.60.0 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.60.0"
  name="${local.environment}"
  cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = []
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  assign_generated_ipv6_cidr_block = true
  enable_nat_gateway = false

  tags = {
    Environment = "${local.environment}"
  }
  vpc_tags = {
    Name = "${local.environment}"
  }
}

resource "aws_security_group" "all_out" {
  name        = "all_out"
  description = "security group that allow outbound traffics"
  vpc_id      = "${module.vpc.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${local.environment}"
    Organization = "gen3"
  }
}

resource "aws_security_group" "web_in" {
  name        = "web_in"
  description = "allow inbound 80 and 443"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${local.environment}"
    Organization = "gen3"
  }
}

resource "aws_security_group" "ssh_in" {
  name        = "ssh_in"
  description = "allow inbound 22"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = "${local.environment}"
    Organization = "gen3"
  }
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
  key_name   = "${local.environment}_automation_dev"
  public_key = "${var.ssh_public_key}"
}

# https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/1.21.0
resource "aws_instance" "cluster" {
  # Note - this number should match the number of eip's setup below
  count                  = "${var.instance_count}"

  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.instance_type}"
  key_name               = "${aws_key_pair.automation_dev.key_name}"
  monitoring             = false
  vpc_security_group_ids = ["${aws_security_group.all_out.id}", "${aws_security_group.ssh_in.id}", "${aws_security_group.web_in.id}"]
  subnet_id              = "${module.vpc.public_subnets[count.index % 3]}"
  root_block_device {
    volume_size = 50
  }

  user_data = <<EOF
#!/bin/bash 

(
  export DEBIAN_FRONTEND=noninteractive
    
  if which hostnamectl > /dev/null; then
    hostnamectl set-hostname 'lab${count.index}'
  fi
  mkdir -p -m 0755 /var/lib/gen3
  cd /var/lib/gen3
  if ! which git > /dev/null; then
    apt update
    apt install git -y
  fi
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
  /bin/rm -rf nodes
  # add -l debug for more verbose logging
  chef-client --local-mode --node-name littlenode --override-runlist 'role[labvm]'
) 2>&1 | tee /var/log/gen3boot.log
  EOF
  
  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device", "user_data"]
  }
  tags = {
    Name        = "${local.environment}${count.index}"
    Terraform = "true"
    Environment = "${local.environment}"
  }
}


resource "aws_eip" "ips" {
  count = "${var.instance_count}"
  instance = "${aws_instance.cluster.*.id[count.index]}"
  vpc      = true
}
