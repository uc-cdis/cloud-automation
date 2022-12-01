#!/bin/bash
# 
# Deploy the argocd
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

kubectl create namespace argocd-gpe-672
#save the namespace where the script was run, so we can switch back later
export namespace=`kubectl config get-contexts | awk '{ print $5 }' | tail +2`
echo $namespace
kubectl apply -f "${HOME}/Gen3Secrets/00configmap.yaml" -n argocd-gpe-672
kubectl config set-context --current --namespace=argocd-gpe-672
gen3 kube-setup-ingress
kubectl config set-context --current --namespace=$namespace
kubectl apply -f "${GEN3_HOME}/kube/services/argocd/install.yaml" -n argocd-gpe-672

cd $HOME
git clone https://github.com/uc-cdis/gen3-helm.git
git checkout -b develop
cd gen3-helm/helm/
helm upgrade revproxy revproxy --install -n argocd-gpe-672