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
  export no_proxy=${no_proxy:-'localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com'}
fi

export DEBIAN_FRONTEND=noninteractive

export vpc_name=${vpc_name:-$1}
export s3_bucket=${s3_bucket:-$2}

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

export GEN3_HOME=~/cloud-automation
source ~/cloud-automation/gen3/gen3setup.sh

gen3 kube-setup-workvm

mkdir -p ~/.aws
mkdir -p ~/${vpc_name}
#mv credentials ~/.aws
cd ~/"${vpc_name}_output"

for fileName in cluster.yaml 00configmap.yaml creds.json; do
  if [[ -f "${fileName}" && ! -f ~/"${vpc_name}/${fileName}" ]]; then
    cp ${fileName} ~/${vpc_name}/
    mv "${fileName}" "${fileName}.bak"
  else
    echo "Using existing ~/${vpc_name}/${fileName}"
  fi
done

cd ~/${vpc_name}

# Add a little guard
if kubectl get nodes > /dev/null 2>&1; then
  echo "It looks like you already have a k8s cluster - bailing out without running kube-aws"
  echo "Run kube-aws directly if you want to apply updates to an existing cluster"
  exit 1
fi

#if [[ -f cluster.yaml ]]; then # setup a kube-aws cluster
#  if [[ ! -d ./credentials ]]; then
#    kube-aws render credentials --generate-ca
#  fi
#  kube-aws render || true

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

  # New kube-aws version doesn't need the s3-uri argument
  #gen3 arun kube-aws validate #--s3-uri "s3://${s3_bucket}/${vpc_name}"
  #gen3 arun kube-aws up #--s3-uri "s3://${s3_bucket}/${vpc_name}"

#  cat - <<EOM
#The kube-aws cluster is up; now add an entry in route53 for the CSOC account.
#Ask Renuka or Fauzi to add k8s-${vpc_name}.internal.io as CNAME for
#the k8s controller load balancer:
#    aws elb describe-load-balancers | grep DNSName | grep ${vpc_name}

#$(aws elb describe-load-balancers | grep DNSName | grep ${vpc_name})

#EOM

#fi
# else running some other k8s flavor (EKS, GKE, ...)

if [[ -n "${s3_bucket}" ]]; then
  # Back everything up to s3
  gen3 kube-backup
fi


