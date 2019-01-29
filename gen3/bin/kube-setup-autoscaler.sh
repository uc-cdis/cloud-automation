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
if ! g3kubectl --namespace=kube-system get deployment cluster-autoscaler > /dev/null 2>&1; then
  k8s_version="$(g3kubectl version -o json |jq -r '.serverVersion.gitVersion')"
  #if [[ ${k8s_version} =~ -eks$ ]]; then tkv=$(echo ${k8s_version}| sed  's/\-eks//' ); k8s_version="${tkv}"; fi
  if [[ ${k8s_version} =~ -eks.*$ ]]; then tkv=${k8s_version//-eks*/}; k8s_version="${tkv}"; fi
  sed "s/VPC_NAME/${vpc_name}/"  "${GEN3_HOME}/kube/services/autoscaler/cluster-autoscaler-autodiscover.yaml" | g3kubectl "--namespace=kube-system" apply -f -
  g3kubectl "--namespace=kube-system" apply -f "${GEN3_HOME}/kube/services/autoscaler/node-drainer-sa.yaml"
  sed -e "s/VPC_NAME/${vpc_name}/" -e "s/K8S_VERSION/${k8s_version}/"  "${GEN3_HOME}/kube/services/autoscaler/kube-node-drainer-asg-status-updater-de.yaml" | g3kubectl "--namespace=kube-system" apply -f -
  sed "s/K8S_VERSION/${k8s_version}/"  "${GEN3_HOME}/kube/services/autoscaler/kube-node-drainer-ds.yaml" | g3kubectl "--namespace=kube-system" apply -f -
fi
