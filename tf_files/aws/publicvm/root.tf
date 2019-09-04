terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

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

data "aws_vpc" "vpc" {
    filter {
        name   = "tag:Name"
        values = ["${var.vpc_name}"]
    }
}

data "aws_subnet" "public" {
  filter {
      name   = "tag:Name"
      values = ["${var.subnet_name}"]
  }
  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_security_group" "ssh_in" {
  filter {
      name   = "group-name"
      values = ["${var.ssh_in_secgroup}"]
  }
  vpc_id = "${data.aws_vpc.vpc.id}"
}

data "aws_security_group" "egress" {
  filter {
      name   = "group-name"
      values = ["${var.egress_secgroup}"]
  }
  vpc_id = "${data.aws_vpc.vpc.id}"
}



resource "aws_iam_role" "role" {
  name = "${var.vpc_name}-public_role"
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

  tags = {
    tag-key = "${var.vpc_name}-public"
  }
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.vpc_name}-public_instance-profile"
  role = "${aws_iam_role.role.name}"
}


resource "aws_iam_policy_attachment" "profile-attach" {
  count      = "${length(var.policies)}"
  name       = "${var.vpc_name}-public-${count.index}"
  roles      = ["${aws_iam_role.role.name}"]
  policy_arn = "${element(var.policies,count.index)}"
}


resource "aws_instance" "cluster" {
  ami                    = "${var.ami == "" ? data.aws_ami.ubuntu.id : var.ami}"
  instance_type          = "${var.instance_type}"
  monitoring             = false
  vpc_security_group_ids = ["${data.aws_security_group.ssh_in.id}", "${data.aws_security_group.egress.id}"]
  subnet_id              = "${data.aws_subnet.public.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.profile.name}"
  root_block_device {
    volume_size = "${var.volume_size}"
    encrypted   = true
  }

  user_data = <<EOF
#!/bin/bash 

(
  # put reuben's key on the machine
  if [[ ! -f /home/ubuntu/.ssh/authorized_keys ]]; then
    mkdir -p /home/ubuntu/.ssh/authorized_keys
    chown ubuntu: /home/ubuntu/.ssh/authorized_keys
    chmod 0600 /home/ubuntu/.ssh/authorized_keys
  fi
  cat - >> /home/ubuntu/.ssh/authorized_keys <<EOM
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfX+T2c3+iBP17DS0oPj93rcQH7OgTCKdjYS0f9s8sIKjErKCao0tRNy5wjBhAWqmq6xFGJeA7nt3UBJVuaGFbszIzs+yvjZYYVrJQdfl0yPbrKRMd/Ch77Jnqbu97Uyu8UxhGkzqEcxQrdBqhqkakhQULjcjZBnk0M1PrLwW+Pl1kRCnXnX/x3YzDR/Ltgjc57qjPbqz7+CBbuFo5OCYOY94pcXetHskvx1AAQ7ZT2c/F/p6vIH5jPKnCTjuqWuGoimp/alczLMO6n+aHgzqc9NKQUScxA0fCGxFeoEdd6b370E7j8xXMIA/xSmq8lFPam+fm3117nC4m29sRktoBI8YP4L7VPSkM/hLp/vRzVJf6U183GfvUSZPERrg+NvMeah9vgkTgzH0iN1+s2xPj6eFz7VUOQtLYTchMZ/qyyGhUzJznY0szocVd6iDbMAYm67R+QtgYEBD1hYrtUD052imb62nEXHFSL3V6369GaJ+k5BIUTGweOaUxGbJlb6fG2Aho4EWaigYRMtmlKgDFaCeJGjlQrFR9lKFzDBc3Af3RefPDVsavYGdQQRUAmueGjlks99Bvh2U53HQgQvc0iQg3ijey2YXBr6xFCMeG7MJZbPcrlQLXko4KygK94EcDPZnIH542CrtAySk/UxxwZv5u0dLsh7o+ZK9G6PO1+Q== reubenonrye@uchicago.edu
EOM
)
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
  cat ./files/authorized_keys/ops_team | tee -a /home/ubuntu/.ssh/authorized_keys

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
  chef-client --chef-license accept --version
  chef-client --local-mode --node-name littlenode --override-runlist 'role[devbox]'
) 2>&1 | tee /var/log/gen3boot.log
  EOF
  
  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "root_block_device", "ebs_block_device", "user_data"]
  }
  tags = {
    Name        = "${var.vpc_name}-public"
    Terraform = "true"
    Environment = "${var.vpc_name}"
  }
}

resource "aws_eip" "ips" {
  instance = "${aws_instance.cluster.id}"
  vpc      = true
}

