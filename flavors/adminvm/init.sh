#!/bin/bash

#SUB_FOLDER="/home/ubuntu/cloud-automation/"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"


if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
else
    #OIFS=$IFS
    IFS=';' read -ra ADDR <<< "$1"
    for i in "${ADDR[@]}"; do
      if [[ $i = *"account_id"* ]];
      then
        ACCOUNT_ID="$(echo ${i} | cut -d= -f2)"
      fi
    done
    echo $1
fi



#CSOC-ACCOUNT-ID=$(${AWS} sts get-caller-identity --output text --query 'Account')
sudo apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
#sudo pip install --upgrade pip
#ACCOUNT_ID=$(curl -s ${MAGIC_URL}iam/info | jq '.InstanceProfileArn' |sed -e 's/.*:://' -e 's/:.*//')

# Let's install awscli and configure it
# Adding AWS profile to the admin VM
sudo pip install awscli
sudo mkdir -p /home/ubuntu/.aws
cat <<EOT  >> /home/ubuntu/.aws/config
[default]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
[profile csoc]
output = json
region = us-east-1
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
EOT
sudo chown ubuntu:ubuntu -R /home/ubuntu

# configure SSH properly
sudo cp $(dirname $0)/sshd_config /etc/ssh/sshd_config
sudo chown root:root /etc/ssh/sshd_config
sudo chmod 0644 /etc/ssh/sshd_config

sudo mkdir -p /usr/local/etc/ssh
sudo cp $(dirname $0)/krlfile /usr/local/etc/ssh/krlfile
sudo chown root:root /usr/local/etc/ssh/krlfile
sudo chmod 0600 /usr/local/etc/ssh/krlfile
cat /home/ubuntu/.ssh/authorized_keys > /root/.ssh/authorized_keys
sudo systemctl restart sshd



HOSTNAME_BIN=$(which hostname)
HOSTNAME=$(${HOSTNAME_BIN})
PYTHON=$(which python)

# download and install awslogs
sudo wget -O /tmp/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
sudo chmod 775 /tmp/awslogs-agent-setup.py
sudo mkdir -p /var/awslogs/etc/
sudo cp $(dirname $0)/awslogs.conf /var/awslogs/etc/awslogs.conf
curl -s ${MAGIC_URL}placement/availability-zone > /tmp/EC2_AVAIL_ZONE
sudo ${PYTHON} /tmp/awslogs-agent-setup.py --region=$(awk '{print substr($0, 1, length($0)-1)}' /tmp/EC2_AVAIL_ZONE) --non-interactive -c $(dirname $0)/awslogs.conf
sudo systemctl disable awslogs
sudo chmod 644 /etc/init.d/awslogs

## now lets configure it properly

sudo sed -i 's/SERVER/auth-{hostname}-{instance_id}/g' /var/awslogs/etc/awslogs.conf
sudo sed -i 's/VPC/'${HOSTNAME}'/g' /var/awslogs/etc/awslogs.conf
cat >> /var/awslogs/etc/awslogs.conf <<EOM
[syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
log_stream_name = syslog-{hostname}-{instance_id}
time_zone = LOCAL
log_group_name = ${HOSTNAME}
EOM
sudo chmod 755 /etc/init.d/awslogs
sudo systemctl enable awslogs
sudo systemctl restart awslogs



########## Admin VM stuff ################

# Install docker from sources
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce
sudo mkdir -p /etc/docker
sudo cp $(dirname  $0)/daemon-daemon.json /etc/docker/daemon.json
sudo chmod -R 0644 /etc/docker
sudo usermod -a -G docker ubuntu
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo cp $(dirname $0)/docker-proxy.conf /etc/systemd/system/docker.service.d/http-proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker


# More basic packages 
sudo apt-get -y install xz-utils bzip2 gnupg wget graphviz unzip

# Terraform 
## assuming we always want the latest stable version 
#sudo wget -O /tmp/terraform.zip  $(echo "https://releases.hashicorp.com/terraform/$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')/terraform_$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')_linux_amd64.zip")

## Otherwise get an specific version
sudo wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.11.10/terraform_0.11.10_linux_amd64.zip
sudo unzip /tmp/terraform.zip -d /tmp
sudo mv /tmp/terraform /usr/local/bin
sudo chmod +x /usr/local/bin/terraform

#sudo cat <<EOT  >>  /home/ubuntu/.bashrc
#export GEN3_HOME="/home/ubuntu/cloud-automation"
#if [ -f "\$${GEN3_HOME}/gen3/gen3setup.sh" ]; then
#  source "\$${GEN3_HOME}/gen3/gen3setup.sh"
#fi
#EOT

echo "export GEN3_HOME=\"/home/ubuntu/cloud-automation\"
if [ -f \"\${GEN3_HOME}/gen3/gen3setup.sh\" ]; then
  source \"\${GEN3_HOME}/gen3/gen3setup.sh\"
fi" | sudo tee --append /home/ubuntu/.bashrc

export GEN3_HOME="/home/ubuntu/cloud-automation"
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi
gen3 kube-setup-workvm
 

