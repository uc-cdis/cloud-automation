#!/bin/bash
#
# Prep and run kube-aws to deploy the k8s cluster.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-up.sh,
# but can also run this standalone if the environment is
# properly configured.
#

set -e

if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy=${http_proxy:-'http://cloud-proxy.internal.io:3128'}
  export https_proxy=${https_proxy:-'http://cloud-proxy.internal.io:3128'}
  export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io'}
fi

export DEBIAN_FRONTEND=noninteractive

# This guys may not be necesary if we run kube-aws > 0.9.9
vpc_name=${vpc_name:-$1}
s3_bucket=${s3_bucket:-$2}

if [[ -z "${vpc_name}" || -z "${s3_bucket}" ]]; then
   echo "Usage: bash kube-up.sh vpc_name s3_bucket"
   exit 1
fi
if [[ ! -d ~/"${vpc_name}_output" ]]; then
  echo "~/${vpc_name}_output does not exist"
  exit 1
fi

if [[ ! -d ~/cloud-automation ]]; then
  cd ~
  git clone https://github.com/uc-cdis/cloud-automation.git 2>/dev/null || true
fi
source ~/"cloud-automation/tf_files/configs/kube-setup-workvm.sh"


# I think at some point we'll be only running the latest version of kube-aws
# at least c0.9.10 which is currently at -rc3, most likely it'll be released
# as GA soon enough. But if we are using a diferent version, this will fail
# unless we use a couple of cluster.yaml
kube_aws_current=$(kube-aws version | awk '{print $3}')
kube_aws_newest="v0.9.10"

if [ "${kube_aws_current/$kube_aws_newest}" = "$kube_aws_current" ];
then
        mv cluster.yaml cluster-9.10.yaml
        mv cluster-9.9.yaml cluster.yaml
fi

mkdir -p ~/.aws
mkdir -p ~/${vpc_name}
#mv credentials ~/.aws
cd ~/"${vpc_name}_output"

for fileName in cluster.yaml 00configmap.yaml; do
  if [[ ! -f ~/"${vpc_name}/${fileName}" ]]; then
    cp ${fileName} ~/${vpc_name}/
  else
    echo "Using existing ~/${vpc_name}/${fileName}"
  fi
done

cd ~/${vpc_name}
ln -fs ~/cloud-automation/kube/services ~/${vpc_name}/services

# Add a little guard
if kubectl get nodes > /dev/null 2>&1; then
  echo "It looks like you already have a k8s cluster - bailing out without running kube-aws"
  echo "Run kube-aws directly if you want to apply updates to an existing cluster"
  exit 1
fi

if [[ ! -d ./credentials ]]; then
  kube-aws render credentials --generate-ca
fi
kube-aws render || true

#
# When running on the adminvm - we need to assume the role
# in the child account - `gen3 arun` handles that for us
# assuming ~/.aws/config has the required setup 
# under the [default] profile - ex:
#
# [default]
# output = json
# region = us-east-1
# role_session_name = gen3-adminvm
# role_arn = arn:aws:iam::{ACCOUNTID}:role/csoc_adminvm
# credential_source = Ec2InstanceMetadata
#
export GEN3_HOME=~/cloud-automation
source ~/cloud-automation/gen3/gen3setup.sh

if [ "${kube_aws_current/$kube_aws_newest}" = "$kube_aws_current" ];
then
        gen3 arun kube-aws validate --s3-uri "s3://${s3_bucket}/${vpc_name}"
        gen3 arun kube-aws up --s3-uri "s3://${s3_bucket}/${vpc_name}"
else
        gen3 arun kube-aws validate
        gen3 arun kube-aws up
fi


# Back everything up to s3
source ~/cloud-automation/tf_files/configs/kube-backup.sh

if ! kubectl --kubeconfig=kubeconfig get nodes; then
  cat - <<EOM
It looks like kubectl cannot reach the controller.
Most likely you need to add an entry in route53 for the CSCO account.

Ask Renuka or Fauzi to add k8s-${vpc_name}.internal.io as CNAME for
the k8s controller load balancer:
    aws elb describe-load-balancers | grep DNSName | grep ${vpc_name}

$(aws elb describe-load-balancers | grep DNSName | grep ${vpc_name})

EOM

fi
