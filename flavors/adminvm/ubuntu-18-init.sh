#!/bin/bash

###############################################################
# variables
###############################################################
WORK_USER="ubuntu"
HOME_FOLDER="/home/${WORK_USER}"
SUB_FOLDER="${HOME_FOLDER}/cloud-automation"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
AVAILABILITY_ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
REGION=$(echo ${AVAILABILITY_ZONE::-1})
DOCKER_DOWNLOAD_URL="https://download.docker.com/linux/ubuntu"
AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
TERRAFORM_DOWNLOAD_URL="https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip"

HOSTNAME_BIN=$(command -v hostname)
HOSTNAME=$(${HOSTNAME_BIN})
PYTHON=$(command -v python)


###############################################################
# get any variables we want coming from terraform variables 
###############################################################
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
      elif [[ $i = *"vm_role"* ]];
      then
        VM_ROLE="$(echo ${i} | cut -d= -f2)"
      elif [[ $i = *"cwl_group"* ]];
      then
        CWL_GROUP="$(echo ${i} | cut -d= -f2)"
      fi
    done
    echo $1
fi


function install_basics(){
  apt install -y curl jq python-pip apt-transport-https ca-certificates software-properties-common fail2ban libyaml-dev
  # More basic packages 
  apt install -y xz-utils bzip2 gnupg wget graphviz unzip
  pip install --upgrade pip
  pip install awscli boto3
}

function configure_awscli() {

  # Adding AWS profile to the admin VM
  mkdir -p /home/ubuntu/.aws
  cat <<EOT > /home/ubuntu/.aws/config
[default]
output = json
region = ${REGION}
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata

[profile csoc]
output = json
region = ${REGION}
role_session_name = gen3-adminvm
role_arn = arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
EOT
}

function configure_ssh() {

  cp $(dirname $0)/sshd_config /etc/ssh/sshd_config
  chown root:root /etc/ssh/sshd_config
  chmod 0644 /etc/ssh/sshd_config

  mkdir -p /usr/local/etc/ssh
  cp $(dirname $0)/krlfile /usr/local/etc/ssh/krlfile
  chown root:root /usr/local/etc/ssh/krlfile
  chmod 0600 /usr/local/etc/ssh/krlfile
  systemctl restart sshd

  # This seems unnecessary
  cat /home/ubuntu/.ssh/authorized_keys >> /root/.ssh/authorized_keys
}





########### awslogs #####################
function install_awslogs {

  ###############################################################
  # download and install awslogs
  ###############################################################
  wget ${AWSLOGS_DOWNLOAD_URL} -O amazon-cloudwatch-agent.deb
  dpkg -i -E ./amazon-cloudwatch-agent.deb

  # Configure the AWS logs

  #instance_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
  #IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"

  cat >> /opt/aws/amazon-cloudwatch-agent/bin/config.json <<EOF
{
        "agent": {
                "run_as_user": "root"
        },
        "logs": {
                "logs_collected": {
                        "files": {
                                "collect_list": [
                                        {
                                                "file_path": "/var/log/auth.log",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "auth-${HOSTNAME}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "/var/log/syslog",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "syslog-${HOSTNAME}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        }
                                ]
                        }
                }
        }
}
EOF

  if [ -v CWL_GROUP ];
  then
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
    systemctl enable amazon-cloudwatch-agent.service
    systemctl start amazon-cloudwatch-agent.service
  fi
}


function install_docker(){

  ###############################################################
  # Docker
  ###############################################################
  # Install docker from sources
  curl -fsSL ${DOCKER_DOWNLOAD_URL}/gpg | sudo apt-key add -
  add-apt-repository "deb [arch=amd64] ${DOCKER_DOWNLOAD_URL} $(lsb_release -cs) stable"
  apt update
  apt install -y docker-ce
  mkdir -p /etc/docker
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/docker-daemon.json /etc/docker/daemon.json
  chmod -R 0644 /etc/docker
  usermod -a -G docker ${WORK_USER}
}


########## Admin VM stuff ################


function install_terraform(){
  #wget -O /tmp/terraform.zip  $(echo "https://releases.hashicorp.com/terraform/$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')/terraform_$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')_linux_amd64.zip")

  local download_path="/tmp/terraform.zip"
  wget -O ${download_path} ${TERRAFORM_DOWNLOAD_URL}
  unzip ${download_path} -d /usr/local/bin
  chmod +x /usr/local/bin/terraform
}

function configure_gen3(){

  chown ubuntu:ubuntu -R /home/ubuntu
  echo "export GEN3_HOME=\"/home/ubuntu/cloud-automation\"
  if [ -f \"\${GEN3_HOME}/gen3/gen3setup.sh\" ]; then
    source \"\${GEN3_HOME}/gen3/gen3setup.sh\"
  fi" | tee --append /home/ubuntu/.bashrc

  export GEN3_HOME="/home/ubuntu/cloud-automation"
  if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
    source "${GEN3_HOME}/gen3/gen3setup.sh"
  fi

  gen3 kube-setup-workvm
}

function elevate_permissions(){

  cat >> /tmp/adminVM.json <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/csoc_adminvm",
                "Effect": "Allow",
                "Sid": ""
            }
    ]
}
EOF

  cd ${HOME_FOLDER}
  sudo -H -u ${WORK_USER} bash -c "$(command -v aws) iam put-role-policy --role-name ${VM_ROLE} --policy-name ${VM_ROLE}_assume_policy --policy-document file:///tmp/adminVM.json"

}

function main(){
  install_basics
  configure_awscli
  configure_ssh
  install_awslogs
  install_docker
  install_terraform
  configure_gen3
  #elevate_permissions
}

main
