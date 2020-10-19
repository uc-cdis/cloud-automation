#!/bin/bash
#
# Run terraform as a script for updates on EKS.
# This should not be ran as a cron job, it might cause services disruption, so be carefull
#
# Cases in which this script might be useful:
#  1.) EKS reseleased a new minor version and said release came along with a new AMI that terraform picks up.
#        This case should not be disruptive at all
#  2.) A change on the user-data script for the worker nodes, (this MUST be tested before bulk update)
#  3.) Addition/Deletion of ops_team keys [cloud-automation/files/authorized_keys/ops_team]
#

#set -i

# Based on https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

kubeproxy=${kubeproxy:-1.15.11}
coredns=${coredns:-1.6.6}
cni=${cni:-1.6}
calico=${calico:-1.7.5}


while [ $# -gt 0 ]; do
   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi
  shift
done

kube_proxy_image="602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/kube-proxy:v${kubeproxy}"
coredns_image="602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/coredns:v${coredns}"
cni_image="https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-${cni}/config/v${cni}/aws-k8s-cni.yaml"
calico_yaml="https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v${calico}/config/v$(echo ${calico} | sed -e 's/\.[0-9]\+$//')/calico.yaml"

g3kubectl set image daemonset.apps/kube-proxy -n kube-system kube-proxy=${kube_proxy_image}
g3kubectl set image --namespace kube-system deployment.apps/coredns coredns=${coredns_image}
g3kubectl apply -f ${cni_image}
g3kubectl apply -f ${calico_yaml}

# let's make sure the coredns configmap is up to date
# see: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
(
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/coredns.json_XXXXXX")"
  if g3kubectl get configmap coredns -n kube-system -o json | jq -e -r .data.Corefile > "$tempFile" && [[ ${PIPESTATUS[0]} == 0 ]]; then
    if grep 'proxy . /etc/resolv.conf' "$tempFile" > /dev/null && \
      sed -i 's@proxy . /etc/resolv.conf@forward . /etc/resolv.conf@' "$tempFile"; then
      gen3_log_info "patching coredns configmap"
      g3kubectl patch configmap coredns -n kube-system --patch "$(jq -n -r --arg Corefile "$(cat $tempFile)" '.data.Corefile = $Corefile')"
    fi
  else
    gen3_log_warn "Failed to retrieve coredns configmap from kube-system namespace"
  fi
  rm "$tempFile"
)
