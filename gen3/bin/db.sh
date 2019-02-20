#!/bin/bash


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#
# Some helpers for managing multiple databases
# on each of a set of db servers.
#

help() {
  gen3 help db
}

#
# Currently run 3 db servers
# db1=fence
# db2=indexd
#
declare -a gen3DbServerFarm=(server1 server2)


#
# Bootstrap the db/servers.json secret
#
gen3_db_init() {
  local secretPath
  local secretDir
  secretDir="$(gen3_secrets_folder)/dbFarm"
  secretPath="$secretDir/servers.json"
  if [[ ! -f "$secretPath" ]]; then
    # initialize the dbFarm with info for the fence and indexd db servers
    cat - <<EOM
{
  "server1": $(gen3_db_service_creds fence),
  "server2": $(gen3_db_service_creds indexd)
}
EOM > "$secretPath"
  fi
}

#
# Validate that the given server name is in gen3DbServerList
# The idea is we have multiple services distributed over
# a smaller set of servers.  
# The current servers are fence, indexd, and sheepdog.
# Note that currently a server is also a service, 
# but a service may not be a server
#
gen3_db_validate_server() {
  local server
  local it
  server="$1"
  shift
  if [[ -z "$server" ]]; then return 1; fi
  for it in "${gen3DbServerFarm[@]}"; do
    if [[ "$it" == "$server" ]]; then
      return 0
    fi
  done
  return 1
}


#
# Lookup the creds for a given service
#
gen3_db_service_creds() {
  local serviceName=$1
  shift
  
  if [[ -z "$serviceName" ]]; then
    gen3_log_err "gen3_db_service_creds: No serviceName specified"
    return 1
  fi
  
  if g3kubectl get secret "${key}-creds" > /dev/null 2>&1; then
    # prefer to pull creds from secret
    g3kubectl get secret "${key}-creds" -o json | jq -r '.data["creds.json"]' | base64 --decode
  elif [[ -z "$JENKINS_HOME" && -f "$(gen3_secrets_folder)/creds.json" ]]; then
    jq -r ".${key}" < "$(gen3_secrets_folder)/creds.json"
  else
    gen3_log_err "unable to find ${key}-creds k8s secret or creds.json"
    return 1
  fi
}

gen3_db_server_info() {
  local secretPath
  echo "${gen3DbServerFarm[@]}"
}


#
# List the databases on a given server
#
gen3_db_list() {
  local server
  server="$1"
  shift

  if ! gen3_db_validate_server "$server"; then
    gen3_log_err "gen3_db_list requires server name"
    return 1
  fi
  gen3 psql "$server" --list | grep '|' | grep fence_user | awk -F '|' '{ gsub(/ /, "", $1); if($1 != ""){ print $1 } }'
}

#
# List the users on a given server
#
gen3_db_user_list() {
  local server
  server="$1"
  shift

  if ! gen3_db_validate_server "$server"; then
    gen3_log_err "gen3_db_list requires server name"
    return 1
  fi
  gen3 psql "$server" -c 'SELECT u.usename FROM pg_catalog.pg_user u';
}


gen3_db_service_setup() {
  local server
  local service
  
  if [[ $# -lt 2 ]]; then
    gen3_log_err "gen3_db_setup SERVER SERVICE"
    return 1
  fi

  server="$1"
  shift
  service="$1"
  shift

  if [[ ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "gen3_db_setup requires $(gen3_secrets_folder)/creds.json"
    return 1
  fi
  if g3kubectl get secret "${service}-creds" > /dev/null 2>&1; then
    gen3_log_err "gen3_db_setup ${service}-creds secret already exists"
    return 1
  fi
  if [[ null != "$(jq -r ".[\"${service}\"]" < "$(gen3_secrets_folder)/creds.json")" ]]; then
    gen3_log_err "gen3_db_setup ${service} already exists in creds.json"
    return 1
  fi

  if ! gen3_db_validate_server "$server"; then
    gen3_log_err "gen3_db_setup invalid server $server"
    return 1
  fi
  if [[ -n "$JENKINS_HOME" ]]; then
    gen3_log_err "gen3_db_setup NOOP in JENKINS"
    return 1
  fi
  
  # ok - we're going to create a new database - maybe a new user too ...
  local dbname
  local username
  local namespace
  local ctx
  local ctxNamespace
  local password
  local it

  ctx="$(g3kubectl config current-context)"
  ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"
  namespace="${KUBECTL_NAMESPACE:-$ctxNamespace}"
  dbname="${service}_${namespace}"
  username="${service}_${namespace}"
  password="$(random_alphanumeric)"

  for it in $(gen3_db_list "$server"); do
    if [[ "$it" == "$dbname" ]]; then
      gen3_log_err "$dbname database already exists"
      return 1
    fi
  done
  for it in $(gen3_user_list "$server"); do 
  done
}