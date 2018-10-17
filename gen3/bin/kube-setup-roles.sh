#!/bin/bash
# 
# Little helper to deploy the k8s resources around
# the useryaml cron job in the correct order.
#
# Assumes this runs in the same directory as the .yaml files
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if [[ -z "$_KUBES_SH" ]]; then
  source "$GEN3_HOME/gen3/gen3setup.sh"
fi # else already sourced this file ...

# Don't do this in a Jenkins job
if [[ -z "$JENKINS_HOME" ]]; then
  if ! g3kubectl get serviceaccounts/useryaml-job > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/useryaml-serviceaccount.yaml"
  fi

  if ! g3kubectl get rolebindings/useryaml-binding > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/useryaml-rolebinding.yaml"
  fi

  if ! g3kubectl get serviceaccounts/jenkins-service > /dev/null 2>&1; then  
    g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/serviceaccount.yaml"
  fi
  if ! g3kubectl get rolebindings/devops-binding > /dev/null 2>&1; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/rolebinding-devops.yaml"
  fi
else
  echo "Not setting up roles in Jenkins: $JENKINS_HOME"
fi

echo "kube-setup-roles done" # force zero exit code
