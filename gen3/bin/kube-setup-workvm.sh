#!/bin/bash
#
# Install the tools on a VPC's 'admin' VPC necessary to
# administer the VPC.
# Assumes 'sudo' access.
#

vpc_name="${vpc_name:-${1:-unknown}}"
s3_bucket="${s3_bucket:-${2:-unknown}}"

# Make it easy to run this directly ...
_setup_workvm_dir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_setup_workvm_dir}/../.." && pwd)}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if sudo -n true > /dev/null 2>&1 && [[ $(uname -s) == "Linux" ]]; then
  # -E passes through *_proxy environment
  sudo -E apt-get update
  sudo -E apt-get install -y git jq postgresql-client pwgen python-dev python-pip unzip
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install --upgrade pip
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install awscli --upgrade
  # jinja2 needed by render_creds.py
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install jinja2
  # yq === jq for yaml
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install yq

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

  if [[ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]]; then
    # might need to uninstall gcloud installed from ubuntu repo
    if which gcloud > /dev/null 2>&1; then
      sudo -E apt-get remove -y google-cloud-sdk
    fi
  fi
  if ! which gcloud > /dev/null 2>&1; then
    (
      export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
      sudo -E bash -c "echo 'deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main' > /etc/apt/sources.list.d/google-cloud-sdk.list"
      curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo -E apt-key add -
      sudo -E apt-get update
      sudo -E apt-get install -y google-cloud-sdk \
          google-cloud-sdk-cbt \
          kubectl
      if [[ -f /usr/local/bin/kubectl && -f /usr/bin/kubectl ]]; then  # pref dpkg managed kubectl
        sudo -E /bin/rm /usr/local/bin/kubectl
      fi
    )
  fi

  mkdir -p ~/.config
  sudo chown -R "${USER}:" ~/.config
      
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
  if ! which heptio-authenticator-aws > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/heptio-authenticator-aws" https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.3.0/heptio-authenticator-aws_0.3.0_linux_amd64
    sudo mv "${XDG_RUNTIME_DIR}/heptio-authenticator-aws" /usr/local/bin
  fi
fi

if which gcloud > /dev/null 2>&1; then
  gcloud config set core/disable_usage_reporting true
  gcloud config set component_manager/disable_update_check true
#  gcloud config set container/use_v1_api false
fi

CURRENT_SHELL="$(echo $SHELL | awk -F'/' '{print $NF}')"
RC_FILE="${CURRENT_SHELL}rc"

if [[ "$WORKSPACE" == "$HOME" ]]; then
  if ! grep GEN3_NOPROXY ${WORKSPACE}/.${RC_FILE} > /dev/null; then
    echo "Adding variables to ${WORKSPACE}/.${RC_FILE}"
    cat - >>${WORKSPACE}/.${RC_FILE} << EOF
export GEN3_NOPROXY='$GEN3_NOPROXY'
if [[ -z "\$GEN3_NOPROXY" ]]; then
  export http_proxy='${http_proxy:-"http://cloud-proxy.internal.io:3128"}'
  export https_proxy='${https_proxy:-"http://cloud-proxy.internal.io:3128"}'
  export no_proxy='$no_proxy'
fi
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

  if ! grep "aws_.*completer" ${WORKSPACE}/.${RC_FILE} > /dev/null ; then
    if [[ ${CURRENT_SHELL} == "zsh" ]]; then
      cat - >>${WORKSPACE}/.${RC_FILE} << EOF
source /usr/local/bin/aws_zsh_completer.sh
EOF
    elif [[ ${CURRENT_SHELL} == "bash" ]]; then
      cat - >>${WORKSPACE}/.${RC_FILE} << EOF
complete -C '/usr/local/bin/aws_completer' aws
EOF
    fi
  fi

# a user login should only work with one vpc
if [[ "$vpc_name" != "unknown" ]] && ! grep 'vpc_name=' ${WORKSPACE}/.${RC_FILE} > /dev/null; then
  cat - >>${WORKSPACE}/.${RC_FILE} <<EOF
export vpc_name='$vpc_name'
export s3_bucket='$s3_bucket'

if [ -f "${WORKSPACE}/\$vpc_name/kubeconfig" ]; then
  export KUBECONFIG="${WORKSPACE}/\$vpc_name/kubeconfig"
fi

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
