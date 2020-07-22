#!/bin/bash
#
# The optional jupyterhub setup for workspaces

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

hatcherySetupSecrets() {
  local roleName
  local saName="hatchery-service-account"
  roleName="$(gen3 api safe-name hatchery)" || return 1
  [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" && -n "$KUBECONFIG" && -f "$KUBECONFIG" ]] || return 1
  #
  # just need an arbitrary role for now, that
  # later will assume hatchery worker roles with access to worker
  # kubernetes clusters
  #
  if ! gen3 awsrole info "$roleName" > /dev/null; then # setup role
    gen3 awsrole create "$roleName" "$saName" || return 1
  fi

  local accountName
  accountName="$(aws iam list-account-aliases | jq -e -r '.AccountAliases[0]')" || return 1
  local clusterName="${accountName}--$(gen3 api environment)--$(gen3 api namespace)"
  local secretsFolder="$(gen3_secrets_folder)/g3auto/hatchery/"
  if ! g3kubectl get secret hatchery-g3auto 2> /dev/null && [[ ! -f "$secretsFolder"  ]]; then
    mkdir -p "$secretsFolder"
    yq -r . < "$KUBECONFIG" > "$secretsFolder/${clusterName}.kubeconfig.json"
    gen3 secrets sync 'chore(hatchery): setup hatchery-g3auto'
  fi
}


# Jenkins friendly
export WORKSPACE="${WORKSPACE:-$HOME}"

namespace="$(gen3 db namespace)"
notebookNamespace="$(gen3 jupyter j-namespace)"

gen3 jupyter j-namespace setup
[[ -z "$GEN3_ROLL_ALL" ]] && gen3 gitops configmaps

g3kubectl apply -f "${GEN3_HOME}/kube/services/hatchery/hatchery-service.yaml"
hatcherySetupSecrets
gen3 roll hatchery
gen3 job cron hatchery-reaper '@daily'
