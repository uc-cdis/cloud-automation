#!/bin/bash
# Deploy Argo Events, and then optionally deploy resources to create Karpenter resources when a workflow is launched 

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"
gen3_load "gen3/lib/g3k_manifest"

ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"
create_workflow_resources=false
force=false
override_namespace=false

for arg in "${@}"; do
  if [ "$arg" == "--create-workflow-resources" ]; then
    create_workflow_resources=true
  elif [ "$arg" == "--force" ]; then
    force=true
  elif [ "$arg" == "--override-namespace" ]; then
    override_namespace=true
  else 
    #Print usage info and exit
    gen3_log_info "Usage: gen3 kube-setup-argo-events [--create-workflow-resources] [--force] [--override-namespace]"
    exit 1
  fi
done

#Check if argo-events namespace exists, if not create it
if ! kubectl get namespace argo-events > /dev/null 2>&1; then
  gen3_log_info "Creating argo-events namespace, as it was not found"
  kubectl create namespace argo-events
fi

if [[ "$ctxNamespace" == "default" || "$ctxNamespace" == "null" || "$override_namespace" == true ]]; then
  if (! helm status argo -n argo-events > /dev/null 2>&1 )  || [[ "$force" == true ]]; then
    helm repo add argo https://argoproj.github.io/argo-helm --force-update 2> >(grep -v 'This is insecure' >&2)
    helm repo update 2> >(grep -v 'This is insecure' >&2)
    helm upgrade --install argo argo/argo-events -n argo-events --version "2.1.3"
  else
    gen3_log_info "argo-events Helm chart already installed. To force reinstall, run with --force"
  fi

  if kubectl get statefulset eventbus-default-stan -n argo-events >/dev/null 2>&1; then
    gen3_log_info "Detected eventbus installation. To reinstall, please delete the eventbus first. You will need to delete any EventSource and Sensors currently in use"
  else
    kubectl apply -f ${GEN3_HOME}/kube/services/argo-events/eventbus.yaml
  fi 
else
  gen3_log_info "Not running in default namespace, will not install argo-events helm chart"
fi

if [[ "$create_workflow_resources" == true ]]; then
  for file in ${GEN3_HOME}/kube/services/argo-events/workflows/*.yaml; do
    kubectl apply -f "$file"
  done

  #Creating rolebindings to allow Argo Events to create jobs, and allow those jobs to manage Karpenter resources
  kubectl create rolebinding argo-events-job-admin-binding --role=job-admin --serviceaccount=argo-events:default --namespace=argo-events
  kubectl create clusterrolebinding karpenter-admin-binding --clusterrole=karpenter-admin --serviceaccount=argo-events:default
fi 