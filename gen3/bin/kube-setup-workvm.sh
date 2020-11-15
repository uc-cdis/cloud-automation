#!/bin/bash
#
# Install the tools on a VPC's 'admin' VPC necessary to
# administer the VPC.
# Assumes 'sudo' access.
#

s3_bucket="${s3_bucket:-${2:-unknown}}"

# Make it easy to run this directly ...
_setup_workvm_dir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_setup_workvm_dir}/../.." && pwd)}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#
# We want kube-setup-workvm to run even if vpc_name
# is not configured, but kube-setup-init will bomb out
# if it cannot derive the vpc_name
#
vpc_name="${vpc_name:-"$(gen3 api environment || echo unknown)"}"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping workvm setup: $JENKINS_HOME"
  exit 0
fi

if sudo -n true > /dev/null 2>&1 && [[ $(uname -s) == "Linux" ]]; then
  # -E passes through *_proxy environment
  sudo -E apt-get update
  sudo -E apt-get install -y git jq pwgen python-dev python-pip unzip python3-dev python3-pip python3-venv 
  sudo -E XDG_CACHE_HOME=/var/cache python3 -m pip install --upgrade pip
  sudo -E XDG_CACHE_HOME=/var/cache python3 -m pip install awscli --upgrade
  # jinja2 needed by render_creds.py
  sudo -E XDG_CACHE_HOME=/var/cache python3 -m pip install jinja2
  # yq === jq for yaml
  sudo -E XDG_CACHE_HOME=/var/cache python3 -m pip install yq

  # install nodejs
  if ! which node > /dev/null 2>&1; then
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
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

    install_terraform12() {
      mkdir "${XDG_RUNTIME_DIR}/t12"
      curl -o "${XDG_RUNTIME_DIR}/t12/terraform12.zip" https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip
      sudo /bin/rm -rf /usr/local/bin/terraform12 > /dev/null 2>&1 || true
      unzip "${XDG_RUNTIME_DIR}/t12/terraform12.zip" -d "${XDG_RUNTIME_DIR}/t12";
      sudo cp "${XDG_RUNTIME_DIR}/t12/terraform" "/usr/local/bin/terraform12"
      /bin/rm -rf "${XDG_RUNTIME_DIR}/t12"
    }

    if ! which terraform > /dev/null 2>&1; then
      install_terraform  
    else
      TERRAFORM_VERSION=$(terraform --version | head -1 | awk '{ print $2 }' | sed 's/^[^0-9]*//')
      if ! semver_ge "$TERRAFORM_VERSION" "0.11.14"; then
        install_terraform
      fi
    fi
    if ! which terraform12 > /dev/null 2>&1; then
      install_terraform12  
    else
      T12_VERSION=$(terraform12 --version | head -1 | awk '{ print $2 }' | sed 's/^[^0-9]*//')
      if ! semver_ge "$T12_VERSION" "0.12.29"; then
        install_terraform12
      fi
    fi
  )

  if [[ -f /etc/systemd/timesyncd.conf ]] \
    && ! grep 169.254.169.123 /etc/systemd/timesyncd.conf > /dev/null \
    && curl -s http://169.254.169.254/latest/meta-data/local-ipv4 > /dev/null; then
      (
      gen3_log_info "updating /etc/systemd/timesyncd.conf to use aws ntp"
      # update ntp to work on AWS in private subnet
      sudo cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.bak
      sudo bash -c 'cat - > /etc/systemd/timesyncd.conf' <<EOM
#  Installed by gen3 kube-setup-workvm
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See timesyncd.conf(5) for details.

[Time]
NTP=169.254.169.123
#FallbackNTP=ntp.ubuntu.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOM
    sudo systemctl restart systemd-timesyncd
    )
  fi
  if ! which packer > /dev/null 2>&1; then
    curl -o "${XDG_RUNTIME_DIR}/packer.zip" https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip
    sudo unzip "${XDG_RUNTIME_DIR}/packer.zip" -d /usr/local/bin
    /bin/rm "${XDG_RUNTIME_DIR}/packer.zip"
  fi
  # https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
  if ! which aws-iam-authenticator > /dev/null 2>&1; then
    (
      gen3_log_info "installing aws-iam-authenticator"
      cd /usr/local/bin
      sudo curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.8/2020-09-18/bin/linux/amd64/aws-iam-authenticator
      sudo chmod a+rx ./aws-iam-authenticator
      sudo rm /usr/local/bin/heptio-authenticator-aws || true
      # link heptio-authenticator-aws for backward compatability with old scripts
      sudo ln -s /usr/local/bin/aws-iam-authenticator heptio-authenticator-aws
    )
  fi
  ( # in a subshell install helm
    install_helm() {
      helm_release_URL="https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz"
      curl -o "${XDG_RUNTIME_DIR}/helm.tar.gz" ${helm_release_URL}
      tar xf "${XDG_RUNTIME_DIR}/helm.tar.gz" -C ${XDG_RUNTIME_DIR}
      sudo mv -f "${XDG_RUNTIME_DIR}/linux-amd64/helm" /usr/local/bin

      # helm3 has no default repo, need to add it manually
      helm repo add stable https://kubernetes-charts.storage.googleapis.com
      helm repo update
    }

    migrate_helm() {
      if ! helm plugin list | grep 2to3 > /dev/null 2>&1; then
        helm plugin install https://github.com/helm/helm-2to3.git
      fi
      helm 2to3 convert grafana
      helm 2to3 convert prometheus
      
      # delete tiller and other helm2 data/configs
      helm 2to3 cleanup --skip-confirmation
    }

    if ! which helm > /dev/null 2>&1; then
      install_helm
    else 
      # Overwrite helm2 with helm3
      if ! helm version --short | grep v3 > /dev/null 2>&1; then
        install_helm
        migrate_helm || true
      fi
    fi
  )

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
if [[ -n "$vpc_name" && "$vpc_name" != "unknown" ]] && ! grep 'vpc_name=' ${WORKSPACE}/.${RC_FILE} > /dev/null; then
  cat - >>${WORKSPACE}/.${RC_FILE} <<EOF
export vpc_name='$vpc_name'
export s3_bucket='$s3_bucket'

if [ -f "${WORKSPACE}/\$vpc_name/kubeconfig" ]; then
  export KUBECONFIG="${WORKSPACE}/\$vpc_name/kubeconfig"
elif [ -f "${WORKSPACE}/Gen3Secrets/kubeconfig" ]; then
  export KUBECONFIG="${WORKSPACE}/Gen3Secrets/kubeconfig"
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

(
  cd "$GEN3_HOME"
  if [[ -f ./package.json ]]; then
    npm install || true
  fi
)
