#!/bin/bash
#
# Just a little helper for deploying jenkins onto k8s the first time
#

set -e

export G3AUTOHOME=${G3AUTOHOME:-~/cloud-automation}

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-jenkins.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

source "${G3AUTOHOME}/kube/kubes.sh"

cd ~/${vpc_name}

#
# Assume Jenkins should use 'jenkins' profile credentials in ~/.aws/credentials
#
aws_access_key_id="$(aws configure get jenkins.aws_access_key_id)"
aws_secret_access_key="$(aws configure get jenkins.aws_secret_access_key)"

if [ -z "$aws_access_key_id" -o -z "$aws_secret_access_key" ]; then
  echo 'ERROR: not configuring jenkins - could not extract secrets from ~/.aws/credentials'
  exit 1
fi

if ! kubectl get secrets/jenkins-secret > /dev/null 2>&1; then
  # make it easy to rerun kube-setup-jenkins.sh
  kubectl create secret generic jenkins-secret "--from-literal=aws_access_key_id=$aws_access_key_id" "--from-literal=aws_secret_access_key=$aws_secret_access_key"
fi

kubectl apply -f services/jenkins/10storageclass.yaml 
kubectl apply -f services/jenkins/00pvc.yaml 

kubectl apply -f services/jenkins/serviceaccount.yaml
kubectl apply -f services/jenkins/role-devops.yaml
kubectl apply -f services/jenkins/rolebinding-devops.yaml

kubectl apply -f services/jenkins/jenkins-deploy.yaml

#
# Get the ARN of the SSL certificate for the commons -
# We'll optimistically assume it's a wildcard cert that
# is appropriate to also attach to the jenkins ELB
#
export ARN=$(kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
if [[ ! -z $ARN ]]; then
  envsubst <services/jenkins/jenkins-service.yaml | kubectl apply -f -
else
  echo "Global configmap not configured - not launching service (require SSL cert ARN)"
fi
