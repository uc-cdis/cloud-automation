#!/bin/bash
#
# Just a little helper for deploying jenkins onto k8s the first time
#

set -e

export WORKSPACE="${WORKSPACE:-$HOME}"
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

#
# Assume Jenkins should use 'jenkins' profile credentials in "${WORKSPACE}"/.aws/credentials
#
aws_access_key_id="$(aws configure get jenkins.aws_access_key_id)"
aws_secret_access_key="$(aws configure get jenkins.aws_secret_access_key)"
google_acct1_email="$(jq -r '.jenkins.google_acct1.email' < $(gen3_secrets_folder)/creds.json)"
google_acct1_password="$(jq -r '.jenkins.google_acct1.password' < $(gen3_secrets_folder)/creds.json)"
google_acct2_email="$(jq -r '.jenkins.google_acct2.email' < $(gen3_secrets_folder)/creds.json)"
google_acct2_password="$(jq -r '.jenkins.google_acct2.password' < $(gen3_secrets_folder)/creds.json)"

if [ -z "$aws_access_key_id" -o -z "$aws_secret_access_key" ]; then
  gen3_log_err 'not configuring jenkins - could not extract secrets from aws configure'
  exit 1
fi
if [[ -z "$google_acct1_email" || -z "$google_acct1_password" || -z "$google_acct2_email" || -z "$google_acct2_password" ]]; then
  gen3_log_err "missing google credentials in '.jenkins' of creds.json"
  exit 1
fi

if ! g3kubectl get secrets jenkins-secret > /dev/null 2>&1; then
  # make it easy to rerun kube-setup-jenkins.sh
  g3kubectl create secret generic jenkins-secret "--from-literal=aws_access_key_id=$aws_access_key_id" "--from-literal=aws_secret_access_key=$aws_secret_access_key"
fi
if ! g3kubectl get secrets google-acct1 > /dev/null 2>&1; then
  g3kubectl create secret generic google-acct1 "--from-literal=email=${google_acct1_email}" "--from-literal=password=${google_acct1_password}"
fi
if ! g3kubectl get secrets google-acct2 > /dev/null 2>&1; then
  g3kubectl create secret generic google-acct2 "--from-literal=email=${google_acct2_email}" "--from-literal=password=${google_acct2_password}"
fi

if ! g3kubectl get storageclass gp2 > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/10storageclass.yaml"
fi
if ! g3kubectl get persistentvolumeclaim datadir-jenkins > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/00pvc.yaml"
fi

# Note: jenkins service account is configured by `kube-setup-roles`
gen3 kube-setup-roles
# Note: only the 'default' namespace jenkins-service account gets a cluster rolebinding
g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/clusterrolebinding-devops.yaml"

# Note: requires Jenkins entry in cdis-manifest
gen3 roll jenkins2
gen3 roll jenkins2-worker
gen3 roll jenkins2-ci-worker

#
# Get the ARN of the SSL certificate for the commons -
# We'll optimistically assume it's a wildcard cert that
# is appropriate to also attach to the jenkins ELB
#
export ARN=$(g3kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
if [[ ! -z $ARN ]]; then
  envsubst <"${GEN3_HOME}/kube/services/jenkins/jenkins-service.yaml" | g3kubectl apply -f -
else
  gen3_log_info "Global configmap not configured - not launching service (require SSL cert ARN)"
fi
