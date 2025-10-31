#!/bin/bash
#
# Deploy auspice into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 roll auspice
g3kubectl apply -f "${GEN3_HOME}/kube/services/auspice/auspice-service.yaml"
ARN=$(g3kubectl get configmap global --output=jsonpath='{.data.revproxy_arn}')
yq --arg ARN "$ARN" '.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-ssl-cert"] = $ARN' < "${GEN3_HOME}/kube/services/auspice/auspice-service-elb.yaml" | g3kubectl apply -f -

cat <<EOM
The auspice service has been deployed onto the k8s cluster.
EOM
