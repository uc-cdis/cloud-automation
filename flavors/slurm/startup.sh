#!/bin/bash
# Copyright 2019 SchedMD LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"

PACKAGES=(
        'bind-utils'
        'environment-modules'
        'epel-release'
        'gcc'
        'git'
        'hwloc'
        'hwloc-devel'
        'libibmad'
        'libibumad'
        'lua'
        'lua-devel'
        'man2html'
        'mariadb'
        'mariadb-devel'
        'mariadb-server'
        'munge'
        'munge-devel'
        'munge-libs'
        'ncurses-devel'
        'nfs-utils'
        'numactl'
        'numactl-devel'
        'openssl-devel'
        'pam-devel'
        'perl-ExtUtils-MakeMaker'
        'python3'
        'python3-pip'
        'readline-devel'
        'rpm-build'
        'rrdtool-devel'
        'vim'
        'wget'
        'tmux'
        'pdsh'
        'openmpi'
        'yum-utils'
    )

PY_PACKAGES=(
        'pyyaml'
        'requests'
        'google-api-python-client'
    )

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

PING_HOST=8.8.8.8
until ( ping -q -w1 -c1 $PING_HOST > /dev/null ) ; do
    echo "Waiting for internet"
    sleep .5
done

echo "apt install -y ${PACKAGES[*]}"
until ( apt install -y ${PACKAGES[*]} > /dev/null ) ; do
    echo "apt failed to install packages. Trying again in 5 seconds"
    sleep 5
done

echo   "pip3 install --upgrade ${PY_PACKAGES[*]}"
until ( pip3 install --upgrade ${PY_PACKAGES[*]} ) ; do
    echo "pip3 failed to install python packages. Trying again in 5 seconds"
    sleep 5
done


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

# SETUP_SCRIPT="setup.py"
# SETUP_META="setup_script"
# DIR="/tmp"
# URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes/$SETUP_META"
# HEADER="Metadata-Flavor:Google"
# echo  "wget -nv --header $HEADER $URL -O $DIR/$SETUP_SCRIPT"
# if ! ( wget -nv --header $HEADER $URL -O $DIR/$SETUP_SCRIPT ) ; then
#     echo "Failed to fetch $SETUP_META:$SETUP_SCRIPT from metadata"
#     exit 1
# fi

# echo "running python cluster setup script"
# chmod +x $DIR/$SETUP_SCRIPT
# $DIR/$SETUP_SCRIPT
