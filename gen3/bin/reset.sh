#!/bin/bash
#
# script to reset kubernetes namespace gen3 objects/services
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# make sure KUBECTL_NAMESPACE env var is set (defaults to current namespace)
if [[ -z $KUBECTL_NAMESPACE ]]; then
    KUBECTL_NAMESPACE=$(g3kubectl get configmap manifest-global -o=jsonpath='{.metadata.namespace}')
    echo "KUBECTL_NAMESPACE set to $KUBECTL_NAMESPACE"
fi

gen3 klock lock reset-lock gen3-reset 3600 -w 60

g3kubectl delete --all deployments --namespace=$KUBECTL_NAMESPACE

# drop and recreate all the postgres databases
services=( fence sheepdog indexd )
for service in ${services[@]}; do
    echo $service
    echo "\c template1 \\\ DROP DATABASE $KUBECTL_NAMESPACE; CREATE DATABASE $KUBECTL_NAMESPACE;" | gen3 psql $service
done

gen3 roll all
gen3 kube-wait4-pods
gen3 runjob gdcdb-create; gen3 runjob indexd-userdb; gen3 runjob usersync
gen3 kube-wait4-pods
gen3 roll all

gen3 klock unlock reset-lock gen3-reset
