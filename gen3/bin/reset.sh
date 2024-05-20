#!/bin/bash
# TODO: Experiencing the following error:
# [31mERROR: 21:00:30 - Lock already exists and timed out waiting for lock to unlock[39m
# + exit 1
# Needs further investigation. Commenting out the next line for now
# set -e

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
        if [[ 0 == "$(g3kubectl get pods -o json | jq -r '[.items[] | { name: .metadata.labels.app } ] | length')" ]]; then
            gen3_log_info "pods are down, ready to drop databases"
            podsDownFlag=0
        else
            sleep 10
            gen3_log_info "pods not done terminating, waiting"
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
  for jobName in gdcdb-create indexd-userdb fence-db-migrate; do
    gen3_log_info "Launching job $jobName"
    gen3 job run $jobName
  done
  gen3_log_info "Waiting for jobs to finish, and late starting services to come up"
  sleep 5
  gen3 kube-wait4-pods default true
  for jobName in gdcdb-create indexd-userdb fence-db-migrate; do
    gen3_log_info "--------------------"
    gen3_log_info "Logs for $jobName"
    gen3 job logs "$jobName"
  done
}

run_post_roll_jobs() {
  local jobName
  #
  # Run some post roll jobs to restore some startup state.
  #
  for jobName in gdcdb-create indexd-userdb usersync; do
    gen3_log_info "Launching job $jobName"
    gen3 job run $jobName
  done
  gen3_log_info "Waiting for jobs to finish, and late starting services to come up"
  sleep 5
  gen3 kube-wait4-pods default true
  for jobName in gdcdb-create indexd-userdb usersync; do
    gen3_log_info "--------------------"
    gen3_log_info "Logs for $jobName"
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
      gen3_log_info "$yesno response, unlocking klock and aborting"
      gen3 klock unlock reset-lock "$LOCK_USER"
      exit 1
  fi
}

#
# both fence db and wts db are wiped out during reset
#
clear_wts_clientId() {
  local appCredsPath
  appCredsPath="$(gen3_secrets_folder)/g3auto/wts/appcreds.json"
  if [ -f "$appCredsPath" ]; then
      gen3_log_info "Removing local wts cred file"
      rm -v "$appCredsPath"
  fi
  if g3kubectl get secret wts-g3auto > /dev/null 2>&1; then
      gen3_log_info "Deleting wts secret appcreds.json key"
      local dbCreds
      dbCreds="$(gen3 secrets decode wts-g3auto dbcreds.json)"
      g3kubectl delete secret wts-g3auto || true
      if [[ -n "$dbCreds" ]]; then
        g3kubectl create secret generic wts-g3auto "--from-literal=dbcreds.json=$dbCreds"
      fi
  fi
  gen3_log_info "All clear for wts"
}

#
# `set -e` can result in locked environment, because on error it will exit without unlocking the environment
#
cleanup() {
  ARG=$?
  gen3 klock unlock reset-lock "$LOCK_USER"
  exit $ARG
}
trap cleanup EXIT

# main ---------------------------

gen3_user_verify "about to drop all service deployments"
gen3_log_info "gen3 klock lock reset-lock "$LOCK_USER" 3600 -w 60"
gen3 klock lock reset-lock "$LOCK_USER" 3600 -w 60
gen3 shutdown namespace
# also clean out network policies
g3kubectl delete networkpolicies --all
wait_for_pods_down
# Give it 30 seconds to ensure connections gets drained
sleep 30
#
# Reset our databases
#
for serviceName in $(gen3 db services); do
  if [[ "$serviceName" != "peregrine" ]]; then  # sheepdog and peregrine share the same db
    if [[ "$serviceName" != "argo"]]; then
      # --force will also drop connections to the database to ensure database gets dropped
      gen3 db reset "$serviceName" --force
    else
      echo "Skipping the Argo DB reset, as that will delete archived workflows."
    fi
  fi
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

# Recreate fence-config k8s secret on every CI run
gen3 kube-setup-secrets

#
# various weird race conditions
# where these setup jobs setup part of a service
# database, and the service itself sets up other parts,
# so run_setup_jobs both before and after roll all to
# try to make reset more reliable - especially in Jenkins
#
if g3kubectl get secret ssjdispatcher-creds > /dev/null 2>&1; then
    aws sqs purge-queue --queue-url="$(gen3 secrets decode ssjdispatcher-creds credentials.json | jq -r .SQS.url)"
fi

run_setup_jobs
clear_wts_clientId

result=0
if ! gen3 roll all; then
  gen3_log_err "the cluster does not look healthy"
  result=1
fi

run_post_roll_jobs

gen3 klock unlock reset-lock "$LOCK_USER"

if [[ "$result" == 0 ]]; then
  gen3_log_info "All done"
else
  gen3_log_err "roll-all had non-zero exit code"
  exit 1
fi
