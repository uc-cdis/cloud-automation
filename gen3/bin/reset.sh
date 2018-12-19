#!/bin/bash
#
# script to reset kubernetes namespace gen3 objects/services
#

# load gen3 tools and set up for resetting namespace
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

# make sure KUBECTL_NAMESPACE env var is set (defaults to current namespace)
if [[ -z $KUBECTL_NAMESPACE ]]; then
    export KUBECTL_NAMESPACE=$(g3kubectl get configmap manifest-global -o=jsonpath='{.metadata.namespace}')
    echo "KUBECTL_NAMESPACE set to $KUBECTL_NAMESPACE"
fi

wait_for_pods_down() {
    podsDownFlag=1
    while [[ podsDownFlag -ne 0 ]]; do
        g3kubectl get pods
        if [[ 0 == "$(g3kubectl get pods -o json | jq -r '[.items[] | { name: .metadata.labels.app } ] | map(select(.name=="fence" or .name=="sheepdog" or .name=="peregrine" or .name=="indexd")) | length')" ]]; then
            echo "pods are down, ready to drop databases"
            podsDownFlag=0
        else
            sleep 10
            echo "pods not done terminating, waiting"
        fi
    done
    return 0
}


gen3 klock lock reset-lock gen3-reset 3600 -w 60

g3kubectl delete --all deployments --namespace=$KUBECTL_NAMESPACE --now
wait_for_pods_down

# drop and recreate all the postgres databases
serviceCreds=( fence-creds sheepdog-creds indexd-creds )
for serviceCred in ${serviceCreds[@]}; do
    dbName=$(g3kubectl get secrets $serviceCred -o json | jq -r '.data["creds.json"]' | base64 --decode | jq -r  .db_database)
    service=${serviceCred%-creds}

    # check for user consent before deleting and recreating tables
    echo -e "$(red_color "WARNING: about to drop the $dbName database from the $service postgres server - proceed? (y/n)")"
    read -r yesno
    if [[ $yesno = "n" ]]; then
        echo "'n' detected, unlocking klock and aborting"
        gen3 klock unlock reset-lock gen3-reset
        exit 1
    fi
    echo "\c template1 \\\ DROP DATABASE \"$KUBECTL_NAMESPACE\"; CREATE DATABASE \"$KUBECTL_NAMESPACE\";" | gen3 psql $service
done

gen3 roll all
gen3 kube-wait4-pods || true
gen3 job run useryaml
# job runs asynchronously ...
gen3 job run gdcdb-create
# also go ahead and setup the indexd auth secrets
gen3 job run indexd-userdb
echo "Sleep 10 seconds for gdcdb-create and indexd-userdb jobs"
sleep 10
gen3 job logs gdcb-create || true
gen3 job logs indexd-userdb || true
echo "Leaving the jobs running in the background if not already done"

gen3 klock unlock reset-lock gen3-reset
