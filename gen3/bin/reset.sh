#!/bin/bash
#
# script to reset kubernetes namespace gen3 objects/services
#

# load gen3 tools and set up for resetting namespace
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"


# lib ---------------------------

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

run_setup_jobs() {
  local jobName
  #
  # Run some setup jobs to restore some startup state.
  # sheepdog wants its transaction tables to exist at startup
  # jobs run asynchronously ...
  #
  for jobName in gdcdb-create indexd-userdb usersync; do
    echo "Launching job $jobName"
    gen3 job run $jobName
  done
  echo "Waiting for jobs to finish, and late starting services to come up"
  sleep 5
  gen3 kube-wait4-pods 
  for jobName in gdcdb-create indexd-userdb usersync; do
    echo "--------------------"
    echo "Logs for $jobName"
    gen3 job logs "$jobName"
  done
}

# main ---------------------------

# check for user consent before deleting and recreating tables
echo -e "$(red_color "WARNING: about to drop all service deployments - proceed? (y/n)")"
read -r yesno
if [[ ! $yesno =~ ^y ]]; then
  exit 1
fi

gen3 klock lock reset-lock gen3-reset 3600 -w 60

g3kubectl delete --all deployments --now
# ssjdispatcher leaves jobs laying around when undeployed
g3kubectl delete --all jobs --now
wait_for_pods_down

# drop and recreate all the postgres databases
serviceCreds=( fence-creds sheepdog-creds indexd-creds )
for serviceCred in ${serviceCreds[@]}; do
    dbName="$(g3kubectl get secrets $serviceCred -o json | jq -r '.data["creds.json"]' | base64 --decode | jq -r  .db_database)"
    service=${serviceCred%-creds}

    # check for user consent before deleting and recreating tables
    echo -e "$(red_color "WARNING: about to drop the $dbName database from the $service postgres server - proceed? (y/n)")"
    read -r yesno
    if [[ $yesno = "n" ]]; then
        echo "'n' detected, unlocking klock and aborting"
        gen3 klock unlock reset-lock gen3-reset
        exit 1
    fi
    #
    # Note: connect to --dbname=template1 to avoid erroring out in
    # situation where the database does not yet exist
    #
    echo "DROP DATABASE \"${dbName}\"; CREATE DATABASE \"${dbName}\";" | gen3 psql $service  --dbname=template1
done

# Make sure peregrine has permission to read the sheepdog db tables
peregrine_db_user="$(g3kubectl get secrets peregrine-creds -o json | jq -r '.data["creds.json"]' | base64 --decode | jq -r  .db_username)"
if [[ -n "$peregrine_db_user" ]]; then
  gen3 psql sheepdog -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $peregrine_db_user; ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
else
  echo -e "$(red_color "WARNING: unable to determine peregrine db username")"
fi

#
# integration tests may muck with user.yaml in fence configmap, so re-sync from S3
# first clear the configmap, so the usersync job sees a diff between S3 and local user.yaml
#
# create a stub user.yaml file that will allow
# arborist to startup with no permissions granted.
#
useryaml="$(mktemp "$XDG_RUNTIME_DIR/user.yaml.XXXXXX")"
cat - > "$useryaml" <<EOM
cloud_providers: {}
groups: {}
resources: {}
users: {}
EOM
g3kubectl delete configmap fence
g3kubectl create configmap fence "--from-file=user.yaml=$useryaml"
/bin/rm "$useryaml"

#
# various weird race conditions 
# where these setup jobs setup part of a service
# database, and the service itself sets up other parts,
# so run_setup_jobs both before and after roll all to
# try to make reset more reliable - especially in Jenkins
# 
run_setup_jobs
gen3 roll all
run_setup_jobs

gen3 klock unlock reset-lock gen3-reset
echo "All done"  # force 0 exit code
