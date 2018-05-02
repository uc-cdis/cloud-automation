#!/bin/bash
#
# Install the tools on a VPC's 'admin' VPC necessary to
# administer the VPC.
# Assumes 'sudo' access.
#

set -e

# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"

if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
  export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
  export no_proxy=${no_proxy:-'localhost,127.0.0.1,localaddress,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com'}
fi

export DEBIAN_FRONTEND=noninteractive

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
vpc_name="${vpc_name:-$1}"
s3_bucket="${s3_bucket:-$2}"

if [ -z "${vpc_name}" ]; then
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
    wget https://github.com/kubernetes-incubator/kube-aws/releases/download/v0.9.10-rc.5/kube-aws-linux-amd64.tar.gz
    tar -zxvf kube-aws-linux-amd64.tar.gz
    chmod -R a+rX linux-amd64
    sudo mv linux-amd64/kube-aws /usr/local/bin
    rm kube-aws-linux-amd64.tar.gz
    rm -r linux-amd64
    #chmod +x kube-aws
    #sudo mv kube-aws /usr/bin
  fi

  if ! which gcloud > /dev/null 2>&1; then
    (
      export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
      sudo -E bash -c "echo 'deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main' > /etc/apt/sources.list.d/google-cloud-sdk.list"
      curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo -E apt-key add -
      sudo -E apt-get update
      sudo -E apt-get install -y google-cloud-sdk \
          google-cloud-sdk-app-engine-python \
          google-cloud-sdk-app-engine-java \
          google-cloud-sdk-app-engine-go \
          google-cloud-sdk-datalab \
          google-cloud-sdk-datastore-emulator \
          google-cloud-sdk-pubsub-emulator \
          google-cloud-sdk-bigtable-emulator \
          google-cloud-sdk-cbt \
          kubectl
      sudo -E gcloud config set core/disable_usage_reporting true
      sudo -E gcloud config set component_manager/disable_update_check true
      if [[ -f /usr/local/bin/kubectl && -f /usr/bin/kubectl ]]; then  # pref dpkg managed kubectl
        sudo -E /bin/rm /usr/local/bin/kubectl
      fi
    )
  fi

  if ! which terraform > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/terraform.zip" https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip
    sudo unzip "${XDG_RUNTIME_DIR}/terraform.zip" -d /usr/local/bin;
    /bin/rm "${XDG_RUNTIME_DIR}/terraform.zip"
  fi
  if ! which packer > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/packer.zip" https://releases.hashicorp.com/packer/1.2.1/packer_1.2.1_linux_amd64.zip
    sudo unzip "${XDG_RUNTIME_DIR}/packer.zip" -d /usr/local/bin
    /bin/rm "${XDG_RUNTIME_DIR}/packer.zip"
  fi
fi

CURRENT_SHELL="$(echo $SHELL | awk -F'/' '{print $NF}')"
RC_FILE="${CURRENT_SHELL}rc"

if [[ "$WORKSPACE" == "$HOME" ]]; then
  if ! grep KUBECONFIG ${WORKSPACE}/.${RC_FILE} > /dev/null; then
    echo "Adding variables to ${WORKSPACE}/.${RC_FILE}"
    cat - >>${WORKSPACE}/.${RC_FILE} << EOF
export http_proxy=http://cloud-proxy.internal.io:3128
export https_proxy=http://cloud-proxy.internal.io:3128
export no_proxy='$no_proxy'

export KUBECONFIG=${WORKSPACE}/${vpc_name}/kubeconfig

EOF
  fi

  if ! grep "kubectl completion ${CURRENT_SHELL}" ${WORKSPACE}/.${RC_FILE} > /dev/null; then 
    cat - >>${WORKSPACE}/.${RC_FILE} << EOF
if which kubectl > /dev/null 2>&1; then
  # Load the kubectl completion code for bash into the current shell
  source <(kubectl completion ${CURRENT_SHELL})
fi
EOF
  fi

# a user login should only work with one vpc
if ! grep 'vpc_name=' ${WORKSPACE}/.${RC_FILE} > /dev/null; then
  cat - >>${WORKSPACE}/.${RC_FILE} <<EOF
export vpc_name='$vpc_name'
export s3_bucket='$s3_bucket'
EOF
  fi

  if ! grep 'GEN3_HOME=' ${WORKSPACE}/.${RC_FILE} > /dev/null; then
    cat - >>${WORKSPACE}/.${RC_FILE} <<EOF
export GEN3_HOME=${WORKSPACE}/cloud-automation
if [ -f "\${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "\${GEN3_HOME}/gen3/gen3setup.sh"
fi
EOF
  fi

  if [[ ! -f ${WORKSPACE}/.aws/config ]]; then
    mkdir -p ${WORKSPACE}/.aws
    cat - >>${WORKSPACE}/.aws/config <<EOF
[default]
output = json
region = us-east-1
# Comment these out if not running on adminvm
role_arn = arn:aws:iam::COMMONS-ACCOUNT-ID-HERE:role/csoc_adminvm
credential_source = Ec2InstanceMetadata

EOF
  fi
fi
