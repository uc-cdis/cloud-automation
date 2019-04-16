#!/bin/bash
#
# script to reset kubernetes namespace gen3 objects/services
#

# load gen3 tools and set up for resetting namespace
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


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

LOCK_USER="gen3-reset-$$"

# 
# Prompt the user with a given message, bail out if user does not reply "yes"
gen3_user_verify() {
  local message="$1"
  local yesno="no"

  # check for user consent before deleting and recreating tables
  gen3_log_warn "$message - proceed? (y/n)"
  read -r yesno
  if [[ $yesno != "y" ]]; then
      echo "$yesno response, unlocking klock and aborting"
      gen3 klock unlock reset-lock "$LOCK_USER"
      exit 1
  fi
}

# main ---------------------------

gen3_user_verify "about to drop all service deployments"
gen3 klock lock reset-lock "$LOCK_USER" 3600 -w 60
g3kubectl delete --all deployments --now
# ssjdispatcher leaves jobs laying around when undeployed
g3kubectl delete --all jobs --now
wait_for_pods_down

#
# Reset our well known databases, and
# the "gen3 db create" databases with -g3auto secrets ...
# scan the -g3auto secrets for `dbcreds.json` ...
#
dbServices=(fence indexd sheepdog)
tempSecrets="$(mktemp "$XDG_RUNTIME_DIR/secrets.json_XXXXXX")"
g3kubectl get secrets -o json | jq -r '.items | map(select( .data["dbcreds.json"] and (.metadata.name|test("-g3auto$")))) | map( { "name": .metadata.name })' > "$tempSecrets"
numSecrets="$(jq -r '. | length' < "$tempSecrets")"
for ((i=0; i < numSecrets; i++)); do
  service="$(jq -r ".[${i}].name" < "$tempSecrets")"
  service="${service%-g3auto}"
  dbServices+=("$service")
done
/bin/rm "$tempSecrets"

for serviceName in "${dbServices[@]}"; do
  gen3 db reset "$serviceName"
done

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

gen3 klock unlock reset-lock "$LOCK_USER"
echo "All done"  # force 0 exit code
