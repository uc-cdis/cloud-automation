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

echo -e "$(red_color "WARNING: about to drop the $db_name database from the $service postgres server - proceed?(Y/N)")"
read -r yesno
if [[ yesno == "N" ]]; then
    exit 1
fi

echo "${WORKSPACE}/${vpc_name}/.rendered_gdcapi_db"
if [[ -f "${WORKSPACE}/${vpc_name}/.rendered_gdcapi_db" ]]; then
    echo "deleting .rendered_gdcapi_db flag file"
    # rm "${WORKSPACE}/${vpc_name}/.rendered_gdcapi_db"
else 
    echo "something wrong with flag file detection"
fi
# g3kubectl delete --all deployments --namespace=$KUBECTL_NAMESPACE

# # drop and recreate all the postgres databases
serviceCreds=( fence-creds sheepdog-creds indexd-creds )
for serviceCred in ${serviceCreds[@]}; do
    echo $serviceCred
    kubectl get secrets serviceCred -o json | jq -r '.data["creds.json"]' | base64 --decode | jq -r  .db_database
    echo "$KUBECTL_NAMESPACE"
#     echo "\c template1 \\\ DROP DATABASE $KUBECTL_NAMESPACE; CREATE DATABASE $KUBECTL_NAMESPACE;" | gen3 psql $service
done

# gen3 roll all
# gen3 kube-wait4-pods
# gen3 job run gdcdb-create; gen3 job run indexd-userdb; gen3 job run usersync
# gen3 kube-wait4-pods
# gen3 roll all

gen3 klock unlock reset-lock gen3-reset
