#!/usr/bin/env bash


export vpc_name="${vpc_name}"
export GEN3_HOME=~/cloud-automation
if [ -f "$${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "$${GEN3_HOME}/gen3/gen3setup.sh"
fi


calico=$${calico:-1.7.5}
calico_yaml="https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v$${calico}/config/v$(echo $${calico} | sed -e 's/\.[0-9]\+$//')/calico.yaml"


#KUBECTL=$(bash which kubectl)
if ! $(command -v kubectl) --kubeconfig "${kubeconfig_path}" get daemonsets -n kube-system calico-node > /dev/null 2>&1; then
  $(command -v kubectl) --kubeconfig "${kubeconfig_path}" apply -f $${calico_yaml}
fi

if ! $(command -v kubectl) --kubeconfig "${kubeconfig_path}" get configmap -n kube-system aws-auth > /dev/null 2>&1; then
  $(command -v kubectl) --kubeconfig "${kubeconfig_path}" apply -f "${auth_configmap}"
fi


