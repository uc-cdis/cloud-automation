#!/bin/bash
#
# Deploy aws-es-proxy into existing commons
# https://github.com/abutaha/aws-es-proxy
# 

#if [ $# -ne 1 ]; then
#    echo "USAGE: $0 name_of_child_vpc"
#    exit 1
#fi

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-secrets

ES_ENDPOINT=$(aws es describe-elasticsearch-domains --domain-names ${vpc_name}-gen3-metadata --query "DomainStatusList[*].Endpoints" --output text)
sed "s/ES_ENDPOINT/https:\/\/${ES_ENDPOINT}/" "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-deploy.yaml" | g3kubectl apply -f -
g3kubectl apply -f "${GEN3_HOME}/kube/services/aws-es-proxy/aws-es-proxy-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_aws_es_proxy.yaml"

cat <<EOM
The aws-es-proxy service has been deployed onto the k8s cluster.
EOM
