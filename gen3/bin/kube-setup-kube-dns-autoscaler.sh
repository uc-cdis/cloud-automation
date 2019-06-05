#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping fluentd setup: $JENKINS_HOME"
  exit 0
fi

#
# Avoid doing this more than once
# We may have multiple commons running on the same k8s cluster,
# but we only have one fluentd.
#
if (! g3kubectl --namespace=kube-system get deployment kube-dns-autoscaler > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then

  DNS_SERVICE=""
  if g3kubectl get deployment -n kube-system kube-dns > /dev/null 2>&1;
  then
    DNS_SERVICE="kube-dns"
  elif g3kubectl get deployment -n kube-system -l coredns > /dev/null 2>&1;
  then
    DNS_SERVICE="coredns"
  fi
  
  if [[ ${DNS_SERVICE} != "" ]];
  then
    echo "Deploying the autoscaler for ${DNS_SERVICE}"
    g3k_kv_filter "${GEN3_HOME}/kube/services/kube-dns-autoscaler/dns-horizontal-autoscaler.yaml" SERVICE "${DNS_SERVICE}" | g3kubectl apply -f -
  fi
  #  g3kubectl apply -f "${GEN3_HOME}/kube/services/kube-dns-autoscaler/dns-horizontal-autoscaler.yaml"
  
fi
