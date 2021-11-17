
resource "aws_cloudwatch_log_group" "csoc_log_group" {
  name              = var.vm_hostname
  retention_in_days = 1827

  tags = {
    Environment  = var.environment
    Organization = var.organization_name
  }
}

resource "aws_ami_copy" "cdis_ami" {
  name              = "${var.vm_name}_ami"
  description       = "A copy of ${data.aws_ami.public_ami.name}"
  source_ami_id     = data.aws_ami.public_ami.id
  source_ami_region = var.aws_region
  encrypted         = true

  tags = {
    Name        = "cdis"
    Environment = var.environment
  }

  lifecycle {
    
    # Do not force update when new ami becomes available.
    # We still need to improve our mechanism for tracking .ssh/authorized_keys
    # User can use 'terraform state taint' to trigger update.
    #
    ignore_changes = [source_ami_id]
  }
}


# Allo SSH Access 

resource "aws_security_group" "ssh" {
  name        = "ssh_${var.vm_name}"
  description = "security group that only enables ssh"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.environment
    Organization = var.organization_name
    Name         = "ssh_${var.vm_name}"
  }
}


# Security group for local traffic

resource "aws_security_group" "local" {
  name        = "local_${var.vm_name}"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.128.0.0/20"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.vpc_cidr_list
  }

  tags = {
    Environment  = var.environment
    Organization = var.organization_name
    Name         = "local_${var.vm_name}"
  }
}

#------- IAM setup ---------------------

#
# basic Role
#
resource "aws_iam_role" "vm_role" {
  name = "${var.vm_name}_role"
  path = "/"

  # https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
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
    Environment  = var.environment
    Organization = var.organization_name
    Name         = "local_${var.vm_name}"
  }
}


resource "aws_iam_role_policy" "vm_policy" {
  name   = "${var.vm_name}_policy"
  policy = data.aws_iam_policy_document.vm_policy_document.json
  role   = aws_iam_role.vm_role.id
}

resource "aws_iam_role_policy" "vm_user_policy" {
  name   = "${var.vm_name}_user_policy"
  role   = aws_iam_role.vm_role.id
  #policy = var.user_policy
  policy = var.user_policy
}


resource "aws_iam_instance_profile" "vm_role_profile" {
  name = "${var.vm_name}_role_profile"
  role = aws_iam_role.vm_role.id
}

locals {

  proxy_config_environment = <<EOF
http_proxy=http://cloud-proxy.internal.io:3128
https_proxy=http://cloud-proxy.internal.io:3128
no_proxy=localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com
EOF

  proxy_config_apt = <<EOF
Acquire::http::Proxy "http://cloud-proxy.internal.io:3128";
Acquire::https::Proxy "http://cloud-proxy.internal.io:3128";
EOF

  profile_d = <<EOF
#!/bin/bash
export http{,s}_proxy=http://cloud-proxy.internal.io:3128
export no_proxy="localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.${data.aws_region.current.name}.amazonaws.com"
EOF
}

resource "aws_instance" "utility_vm" {
  ami                    = aws_ami_copy.cdis_ami.id
  subnet_id              = var.vpc_subnet_id
  instance_type          = var.instance_type
  monitoring             = true
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.local.id]

  iam_instance_profile = aws_iam_instance_profile.vm_role_profile.name

  tags = {
    Name         = var.vm_name
    Environment  = var.environment
    Organization = var.organization_name
  }

  lifecycle {
    ignore_changes = [ami, key_name]
  }

  provisioner "file" {
    content     = var.proxy ? local.proxy_config_apt : ""
    destination = "/tmp/01proxy"
    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = self.private_ip
    }
  }

  provisioner "file" {
    content     = var.proxy ? local.profile_d : ""
    destination = "/tmp/99-proxy.sh"
    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = self.private_ip
    }
  }

  user_data = <<EOF
#!/bin/bash 

cat /tmp/01proxy | tee -a /etc/apt/apt.conf.d/01proxy
cat /tmp/99-proxy.sh | tee /etc/profile.d/99-proxy.sh
chmod +x /etc/profile.d/99-proxy.sh

USER="ubuntu"
USER_HOME="/home/$USER"
CLOUD_AUTOMATION="$USER_HOME/cloud-automation"
(
  source /etc/profile.d/99-proxy.sh
  cd $USER_HOME
  git clone https://github.com/uc-cdis/cloud-automation.git
  cd $CLOUD_AUTOMATION
  git pull
  cat $CLOUD_AUTOMATION/${var.authorized_keys} | sudo tee --append $USER_HOME/.ssh/authorized_keys

  # This is needed temporarily for testing purposes ; before merging the code to master
  if [ "${var.branch}" != "master" ];
  then
    git checkout "${var.branch}"
    git pull
  fi
  chown -R ubuntu. $CLOUD_AUTOMATION

  echo "127.0.1.1 ${var.vm_hostname}" | tee --append /etc/hosts
  hostnamectl set-hostname ${var.vm_hostname}

  apt -y update
  DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade

  apt autoremove -y
  apt clean
  apt autoclean

  cd $USER_HOME

  bash "${var.bootstrap_path}${var.bootstrap_script}" "cwl_group=${aws_cloudwatch_log_group.csoc_log_group.name};vm_role=${aws_iam_role.vm_role.name};account_id=${var.aws_account_id};${join(";",var.extra_vars)}" 2>&1
  cd $CLOUD_AUTOMATION
  git checkout master
) > /var/log/bootstrapping_script.log

# Install qualys agent if the activtion and customer id provided
if [[ ! -z "${var.activation_id}" ]] || [[ ! -z "${var.customer_id}" ]]; then
    aws s3 cp s3://qualys-agentpackage/QualysCloudAgent.rpm ./qualys-cloud-agent.x86_64.rpm
    sudo rpm -ivh qualys-cloud-agent.x86_64.rpm
    # Clean up rpm package after install
    rm qualys-cloud-agent.x86_64.rpm
    sudo /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=${var.activation_id} CustomerId=${var.customer_id}
fi
EOF
}
