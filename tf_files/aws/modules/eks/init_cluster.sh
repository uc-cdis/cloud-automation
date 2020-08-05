#!/usr/bin/env bash




export vpc_name="${vpc_name}"
export GEN3_HOME=~/cloud-automation
if [ -f "$${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "$${GEN3_HOME}/gen3/gen3setup.sh"
fi

#gen3 arun 

#alias kubectl=g3kubectl

#KUBECTL=$(bash which kubectl)
if ! $(command -v kubectl) --kubeconfig "${kubeconfig_path}" get daemonsets -n kube-system calico-node > /dev/null 2>&1; then
  $(command -v kubectl) --kubeconfig "${kubeconfig_path}" apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.5/config/v1.5/calico.yaml
fi

if ! $(command -v kubectl) --kubeconfig "${kubeconfig_path}" get configmap -n kube-system aws-auth > /dev/null 2>&1; then
  $(command -v kubectl) --kubeconfig "${kubeconfig_path}" apply -f "${auth_configmap}"
fi


