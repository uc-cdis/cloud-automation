#!/bin/bash
#
# Install the tools on a VPC's 'admin' VPC necessary to
# administer the VPC.
# Assumes 'sudo' access.
#

set -e

export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io'}
export DEBIAN_FRONTEND=noninteractive

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
vpc_name=${vpc_name:-$1}
s3_bucket=${s3_bucket:-$2}

if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-workvm.sh vpc_name s3_bucket"
   exit 1
fi
if [ -z "${s3_bucket}" ]; then
   echo "Usage: bash kube-setup-workvm.sh vpc_name s3_bucket"
   exit 1
fi

if sudo -n true > /dev/null 2>&1; then
  # -E passes through *_proxy environment
  sudo -E apt-get update
  sudo -E apt-get install -y git jq postgresql-client pwgen python-dev python-pip unzip
  sudo -E XDG_CACHE_HOME=/var/cache pip install --upgrade pip
  sudo -E XDG_CACHE_HOME=/var/cache pip install awscli --upgrade
  # jinja2 needed by render_creds.py
  sudo -E XDG_CACHE_HOME=/var/cache pip install jinja2
  # yq === jq for yaml
  sudo -E XDG_CACHE_HOME=/var/cache pip install yq


  if ! which kube-aws > /dev/null 2>&1; then
    echo "Installing kube-aws"
    wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.8/kube-aws-linux-amd64.tar.gz
    tar -zxvf kube-aws-linux-amd64.tar.gz
    chmod -R a+rX linux-amd64
    sudo mv linux-amd64/kube-aws /usr/local/bin
    rm kube-aws-linux-amd64.tar.gz
    rm -r linux-amd64
    #chmod +x kube-aws
    #sudo mv kube-aws /usr/bin
  fi

  if ! which kubectl > /dev/null 2>&1; then
    echo "Installing kubectl"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod a+rx kubectl
    sudo mv kubectl /usr/local/bin/
  fi

  if ! which terraform > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/terraform.zip" https://releases.hashicorp.com/terraform/0.11.3/terraform_0.11.3_linux_amd64.zip
    sudo unzip "${XDG_RUNTIME_DIR}/terraform.zip" -d /usr/local/bin;
    /bin/rm "${XDG_RUNTIME_DIR}/terraform.zip"
  fi
  if ! which packer > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/packer.zip" https://releases.hashicorp.com/packer/1.2.1/packer_1.2.1_linux_amd64.zip
    sudo unzip "${XDG_RUNTIME_DIR}/packer.zip" -d /usr/local/bin
    /bin/rm "${XDG_RUNTIME_DIR}/packer.zip"
  fi
fi

if ! grep kubes.sh ~/.bashrc > /dev/null; then
  echo "Adding variables to ~/.bashrc"
  cat - >>~/.bashrc << EOF
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io'

export KUBECONFIG=~/${vpc_name}/kubeconfig

if [ -f ~/cloud-automation/kube/kubes.sh ]; then
    . ~/cloud-automation/kube/kubes.sh
fi
EOF
fi

if ! grep 'kubectl completion bash' ~/.bashrc > /dev/null; then 
  cat - >>~/.bashrc << EOF
if which kubectl > /dev/null 2>&1; then
  # Load the kubectl completion code for bash into the current shell
  source <(kubectl completion bash)
fi
EOF
fi

# a provisioner should only work with one vpc
if ! grep 'vpc_name=' ~/.bashrc > /dev/null; then
  cat - >>~/.bashrc <<EOF
export vpc_name='$vpc_name'
export s3_bucket='$s3_bucket'
EOF
fi

if ! grep 'GEN3_HOME=' ~/.bashrc > /dev/null; then
  cat - >>~/.bashrc <<EOF
export GEN3_HOME=~/cloud-automation
if [ -f "\${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\${GEN3_HOME}/gen3/gen3setup.sh"
fi
EOF
fi
