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

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping workvm setup: $JENKINS_HOME"
  exit 0
fi

if sudo -n true > /dev/null 2>&1 && [[ $(uname -s) == "Linux" ]]; then
  # -E passes through *_proxy environment
  sudo -E apt-get update
  sudo -E apt-get install -y git jq pwgen python-dev python-pip unzip
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install --upgrade pip
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install awscli --upgrade
  # jinja2 needed by render_creds.py
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install jinja2
  # yq === jq for yaml
  sudo -E XDG_CACHE_HOME=/var/cache python -m pip install yq

  # install nodejs
  if ! which node > /dev/null 2>&1; then
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    sudo -E apt-get update
    sudo -E apt-get install -y nodejs
  fi
  if [[ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]]; then
    # might need to uninstall gcloud installed from ubuntu repo
    if which gcloud > /dev/null 2>&1; then
      sudo -E apt-get remove -y google-cloud-sdk
    fi
  fi
  if ! which psql > /dev/null 2>&1; then
    (
      # use the postgres dpkg server
      # https://www.postgresql.org/download/linux/ubuntu/
      DISTRO="$(lsb_release -c -s)"  # ex - xenial
      if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then
        echo "deb http://apt.postgresql.org/pub/repos/apt/ ${DISTRO}-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
      fi
      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
      sudo -E apt-get update
      sudo -E apt-get install -y postgresql-client-9.6
    )
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
  
  ( # in a subshell - install terraform
    install_terraform() {
      curl -o "${XDG_RUNTIME_DIR}/terraform.zip" https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip
      sudo /bin/rm -rf /usr/local/bin/terraform > /dev/null 2>&1 || true
      sudo unzip "${XDG_RUNTIME_DIR}/terraform.zip" -d /usr/local/bin;
      /bin/rm "${XDG_RUNTIME_DIR}/terraform.zip"
    }

    if ! which terraform > /dev/null 2>&1; then
      install_terraform  
    else
      TERRAFORM_VERSION=$(terraform --version | head -1 | awk '{ print $2 }' | sed 's/^[^0-9]*//')
      if ! semver_ge "$TERRAFORM_VERSION" "0.11.14"; then
        install_terraform
      fi
    fi
  )
  if ! which packer > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/packer.zip" https://releases.hashicorp.com/packer/1.2.1/packer_1.2.1_linux_amd64.zip
    sudo unzip "${XDG_RUNTIME_DIR}/packer.zip" -d /usr/local/bin
    /bin/rm "${XDG_RUNTIME_DIR}/packer.zip"
  fi
  if ! which heptio-authenticator-aws > /dev/null 2>&1; then
    curl -Lo "${XDG_RUNTIME_DIR}/heptio-authenticator-aws" https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.3.0/heptio-authenticator-aws_0.3.0_linux_amd64
    sudo mv "${XDG_RUNTIME_DIR}/heptio-authenticator-aws" /usr/local/bin
    sudo chmod +x /usr/local/bin/heptio-authenticator-aws
  fi
  if ! which helm > /dev/null 2>&1; then
    helm_release_URL="https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz"
    curl -o "${XDG_RUNTIME_DIR}/helm.tar.gz" ${helm_release_URL}
    tar xf "${XDG_RUNTIME_DIR}/helm.tar.gz" -C ${XDG_RUNTIME_DIR}
    sudo mv "${XDG_RUNTIME_DIR}/linux-amd64/helm" /usr/local/bin
  fi

  # install "update and reboot" cron job
  sudo cp "${GEN3_HOME}/files/scripts/updateAndRebootCron" /etc/cron.d/
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
