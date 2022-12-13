#!/bin/bash
# 
# Deploy the argocd
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if g3kubectl get namespace argocd > /dev/null 2>&1;
then
    gen3_log_info "ArgoCD is already deployed. Skipping..."
else
    kubectl create namespace argocd
    kubectl annotate namespace argocd app="argocd"
    kubectl apply -f "${GEN3_HOME}/kube/services/argocd/install.yaml" -n argocd
    gen3 kube-setup-revproxy
    export argocdsecret=`kubectl get secret argocd-initial-admin-secret -n argocd -o json | jq .data.password -r | base64 -d` # pragma: allowlist secret
    gen3_log_info "You can now access the ArgoCD endpoint with the following credentials: Username= admin and Password= $argocdsecret"
fi