#!/bin/bash
#
# Run terraform as a script for updates on EKS.
# This should not be ran as a crontjob, it might cause services disruption, so be carefull
#
# Cases in which this script might be useful:
#  1.) EKS reseleased a new minor version and said release came along with a new AMI that terraform picks up.
#        This case should not be disruptive at all
#  2.) A change on the user-data script for the worker nodes, (this MUST be tested before bulk update)
#  3.) Addition/Deletion of ops_team keys [cloud-automation/files/authorized_keys/ops_team]
#

#set -i

# Based on https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html

kubeproxy=${kubeproxy:-1.15.11}
coredns=${coredns:-1.6.6}
cni=${cni:-1.6}
while [ $# -gt 0 ]; do
   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi
  shift
done

if ! [[ -d "$HOME/cloud-automation" ]]; then
  echo "ERROR: this does not look like a commons environment"
  exit 1
fi

export vpc_name="$(grep 'vpc_name=' $HOME/.bashrc |cut -d\' -f2)"
export GEN3_HOME="$HOME/cloud-automation"
#export KUBECONFIG="$HOME/${vpc_name}/kubeconfig"
#PATH="${PATH}:/usr/local/bin"


if [[ -z "$XDG_DATA_HOME" ]]; then
  export XDG_DATA_HOME="$HOME/.local/share"
fi
if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi
if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  export XDG_RUNTIME_DIR="/tmp/gen3-$USER-$$"
  mkdir -m 700 -p "$XDG_RUNTIME_DIR"
fi

source "${GEN3_HOME}/gen3/gen3setup.sh"
#gen3 gitops tfplan $@


kube_proxy_image="602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/kube-proxy:v${kubeproxy}"


coredns_image="602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/coredns:v${coredns}"

cni_image="https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-${cni}/config/v${cni}/aws-k8s-cni.yaml"


g3kubectl set image daemonset.apps/kube-proxy -n kube-system kube-proxy=${kube_proxy_image}
g3kubectl set image --namespace kube-system deployment.apps/coredns coredns=${coredns_image}
g3kubectl apply -f ${cni_image}


function get_current_minor_version(){
  local mayor=$(g3kubectl version -o json | jq -r  '.serverVersion.minor' )
  echo ${mayor}
}

