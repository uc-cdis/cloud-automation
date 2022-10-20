resource "aws_cloudwatch_log_group" "csoc_log_group" {
  name              = var.child_name
  retention_in_days = 1827

  tags = {
    Environment  = var.child_name
    Organization = "Basic Services"
  }
}

# Security group to access peered networks from the csoc admin VM
resource "aws_security_group" "ssh" {
  name        = "ssh_${var.child_name}"
  description = "security group that only enables ssh"
  vpc_id      = var.csoc_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment  = var.child_name
    Organization = "Basic Service"
  }
}

resource "aws_security_group" "local" {
  name        = "local_${var.child_name}"
  description = "security group that only allow internal tcp traffics"
  vpc_id      = var.csoc_vpc_id

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
    cidr_blocks = ["10.128.0.0/20", "54.224.0.0/12", var.vpc_cidr_list]
  }

  tags = {
    Environment = var.child_name
  }
}

#------- IAM setup ---------------------

#
# Create a role that can assume the 'admin' role of another account.
# We'll wrap our admin VM with an instance profile that
# injects this role into the VM
#
resource "aws_iam_role" "child_role" {
  name = "${var.child_name}_role"
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
}

resource "aws_iam_role_policy" "child_policy" {
  name   = "${var.child_name}_child_policy"
  policy = data.aws_iam_policy_document.child_policy_document.json
  role   = aws_iam_role.child_role.id
}

resource "aws_iam_instance_profile" "child_role_profile" {
  name = "${var.child_name}_child_role_profile"
  role = aws_iam_role.child_role.id
}

resource "aws_instance" "login" {
  ami                    = data.aws_ami.ubuntu.id
  subnet_id              = var.csoc_subnet_id
  instance_type          = "t2.micro"
  monitoring             = true
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.local.id]
  iam_instance_profile   = aws_iam_instance_profile.child_role_profile.name
  user_data              = <<EOF
#!/bin/bash 
#Proxy configuration and hostname assigment for the adminVM
echo http_proxy=http://cloud-proxy.internal.io:3128 >> /etc/environment
echo https_proxy=http://cloud-proxy.internal.io:3128/ >> /etc/environment
echo no_proxy="localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com"  >> /etc/environment
echo 'Acquire::http::Proxy "http://cloud-proxy.internal.io:3128";' >> /etc/apt/apt.conf.d/01proxy
echo 'Acquire::https::Proxy "http://cloud-proxy.internal.io:3128";' >> /etc/apt/apt.conf.d/01proxy
echo '127.0.1.1 ${var.child_name}_admin' | sudo tee --append /etc/hosts
sudo hostnamectl set-hostname '${var.child_name}'_admin

#Requirements for cloud-automation
cd /home/ubuntu
sudo git clone https://github.com/uc-cdis/cloud-automation.git 
sudo apt install -y unzip
sudo apt-get -y install jq
#sudo wget -O /tmp/terraform.zip  \$(echo "https://releases.hashicorp.com/terraform/$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')/terraform_\$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')_linux_amd64.zip")
sudo wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.5/terraform_0.11.5_linux_amd64.zip
sudo unzip /tmp/terraform.zip -d /tmp
sudo mv /tmp/terraform /usr/local/bin
sudo chmod +x /usr/local/bin/terraform
sudo cat <<EOT  >>  /home/ubuntu/.bashrc
export GEN3_HOME="/home/ubuntu/cloud-automation"
if [ -f "\$${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\$${GEN3_HOME}/gen3/gen3setup.sh"
fi
EOT


# Adding AWS profile to the admin VM
sudo python -m pip install awscli
sudo mkdir -p /home/ubuntu/.aws
sudo cat <<EOT  >> /home/ubuntu/.aws/config
[default]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${var.child_account_id}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
[profile ${var.child_name}]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${var.child_account_id}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
EOT
sudo chown ubuntu:ubuntu -R /home/ubuntu/

# Logging

sed -i 's/SERVER/login_node-auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sed -i 's/VPC/'${aws_cloudwatch_log_group.csoc_log_group.name}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = login_node-syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${aws_cloudwatch_log_group.csoc_log_group.name}
EOM

chmod 755 /etc/init.d/awslogs
systemctl enable awslogs
systemctl restart awslogs
EOF

  root_block_device  {
    volume_size = 24
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami, key_name, root_block_device]
  }

  tags = {
    Name        = "${var.child_name}_admin"
    Environment = var.child_name
  }
}
