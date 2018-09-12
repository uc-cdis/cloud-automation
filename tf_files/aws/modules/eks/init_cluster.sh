#!/usr/bin/env bash




export vpc_name='${var.vpc_name}'
export GEN3_HOME=~/cloud-automation
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi

#gen3 arun 
export $(gen3 arun env | grep AWS_ACCESS_KEY_ID)
export $(gen3 arun env | grep AWS_SECRET_ACCESS_KEY)
export $(gen3 arun env | grep AWS_SESSION_TOKEN)

#alias kubectl=g3kubectl

KUBECTL=$(bash which kubectl)
${KUBECTL} --kubeconfig "${var.kubeconfig_path}" apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.1/config/v1.1/calico.yaml
${KUBECTL} --kubeconfig "${var.kubeconfig_path}" apply -f "${var.auth_configmap}"


