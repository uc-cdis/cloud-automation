#!/bin/bash
#
# Just a little helper for deploying jenkins onto k8s the first time
#

set -e
echo 'Registering Jenkins with k8s'

#
# Assume Jenkins should use the credentials harvested by terraform,
# then copied into ~/.aws/credentials by kube-up.sh ...
#
if [ -f ~/.aws/credentials ]; then
  aws_access_key_id="$(cat ~/.aws/credentials | grep aws_access_key_id | sed 's/.*=//' | sed 's/\s*//g' | head -1)"
  aws_secret_access_key="$(cat ~/.aws/credentials | grep aws_secret_access_key | sed 's/.*=//' | sed 's/\s*//g' | head -1)"
fi
if [ -z "$aws_access_key_id" -o -z "$aws_secret_access_key" ]; then
  echo 'WARNING: not configuring jenkins - could not extract secrets from ~/.aws/credentials'
else
  if ! kubectl get secrets/jenkins-secret > /dev/null 2>&1; then
    # make it easy to rerun deploy_jenkins.sh
    kubectl create secret generic jenkins-secret "--from-literal=aws_access_key_id=$aws_access_key_id" "--from-literal=aws_secret_access_key=$aws_secret_access_key"
  fi
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
    echo "Global configmap not configured"
  fi
fi
