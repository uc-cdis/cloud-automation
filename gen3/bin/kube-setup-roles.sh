#!/bin/bash
# 
# Little helper to deploy the k8s resources around
# the useryaml cron job in the correct order.
#
# Assumes this runs in the same directory as the .yaml files
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

g3kubectl patch serviceaccount default -p 'automountServiceAccountToken: false'
g3kubectl patch serviceaccount --namespace "$(gen3 jupyter j-namespace)" default -p 'automountServiceAccountToken: false' > /dev/null || true

namespace="$(gen3 api namespace)"

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
  if ! g3kubectl get sa gitops-sa > /dev/null 2>&1; then
    roleName="$(gen3 api safe-name gitops)"
    gen3 awsrole create "$roleName" gitops-sa
    # do this here, since we added the new role to this binding
    g3k_kv_filter ${GEN3_HOME}/kube/services/jenkins/rolebinding-devops.yaml CURRENT_NAMESPACE "namespace: $namespace"|g3kubectl apply -f -
  fi
  if ! g3kubectl get rolebindings/devops-binding > /dev/null 2>&1; then
    g3k_kv_filter ${GEN3_HOME}/kube/services/jenkins/rolebinding-devops.yaml CURRENT_NAMESPACE "namespace: $namespace"|g3kubectl apply -f -
  fi

  ctx="$(g3kubectl config current-context)"
  ctxNamespace="$(gen3 db namespace)"
  # only do this if we are running in the default namespace
  if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" ]]; then
    g3kubectl apply -f "${GEN3_HOME}/kube/services/jenkins/clusterrolebinding-devops.yaml"
  fi
else
  gen3_log_info "Not setting up roles in Jenkins: $JENKINS_HOME"
fi

gen3_log_info "kube-setup-roles done" # force zero exit code
