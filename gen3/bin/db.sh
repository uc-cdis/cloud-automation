#!/bin/bash


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#
# Some helpers for managing multiple databases
# on each of a set of db servers.
#

# lib -----------------------------------

gen3_db_help() {
  gen3 help db
}

#
# Currently run 3 db servers
# db1=fence
# db2=indexd
#
declare -a gen3DbServerFarm=(server1 server2)


gen3_db_farm_path() {
  echo "$(gen3_secrets_folder)/dbFarm/servers.json"
}

#
# Bootstrap the db/servers.json secret
#
gen3_db_init() {
  local secretPath
  
  secretPath="$(gen3_db_farm_path)"
  if [[ ! -f "$secretPath" ]]; then
    mkdir -p -m 0700 "$(dirname $secretPath)"
    # initialize the dbFarm with info for the fence and indexd db servers
    (cat - <<EOM
{
  "server1": $(gen3_db_service_creds fence),
  "server2": $(gen3_db_service_creds indexd)
}
EOM
    ) | jq -r . > "$secretPath"
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
  for it in $(gen3_db_server_list); do
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
  local key=$1
  shift
  local credsPath
  credsPath="$(gen3_secrets_folder)/creds.json"
  
  if [[ -z "$key" ]]; then
    gen3_log_err "gen3_db_service_creds: No serviceName specified"
    return 1
  fi
  
  if g3kubectl get secret "${key}-creds" > /dev/null 2>&1; then
    # prefer to pull creds from secret
    g3kubectl get secret "${key}-creds" -o json | jq -r '.data["creds.json"]' | base64 --decode
  elif [[ -z "$JENKINS_HOME" && -f "$credsPath" ]]; then
    jq -e -r ".[\"$key\"]" < "$credsPath"
  else
    gen3_log_err "gen3_db_service_creds - unable to find ${key}-creds k8s secret or creds.json"
    return 1
  fi
}

#
# Select a random server
#
gen3_db_random_server() {
  local total
  local index
  total="$(gen3_db_farm_path | xargs cat | jq -r '. | keys | length')"
  index=$((RANDOM % total))
  gen3_db_farm_path | xargs cat | jq -r ". | keys | .[$index]"
}


#
# List the servers - one per line
#
gen3_db_server_list() {
  gen3_db_farm_path | xargs cat | jq -r '. | keys | join("\n")'
}

#
# Get info about the specified server, or * returns all servers in a map
#
gen3_db_server_info() {
  local server
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_db_server_info must specify server - gen3_db_server_list lists servers"
    echo null
    return 1
  fi
  server="$1"
  shift
  gen3_db_farm_path | xargs cat | jq -e -r ".[\"$server\"]"
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
  gen3_db_psql "$server" --list | grep '|' | grep fence_user | awk -F '|' '{ gsub(/ /, "", $1); if($1 != ""){ print $1 } }'
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
  gen3_db_psql "$server" -c 'SELECT u.usename FROM pg_catalog.pg_user u';
}

#
# Open a psql connection to the specified database
#
# @param serviceName should be one of indexd, fence, sheepdog
#
gen3_db_psql() {
  local key=$1
  shift
  
  if [[ -z "$key" ]]; then
    gen3_log_err "gen3_db_psql: No target specified"
    return 1
  fi

  local credsPath
  local username
  local password
  local host
  local database
  local arg
  credsPath="$(mktemp "${XDG_RUNTIME_DIR}/creds.json.XXXXXX")"
  
  if [[ "$key" =~ ^server[0-9]+$ ]]; then
    if ! gen3_db_server_info "$key" > "$credsPath"; then
      gen3_log_err "gen3_db_psql - unable to find creds for server $key"
      rm -rf "$credsPath"
      return 1
    fi
    database=template1
  else
    if ! gen3_db_service_creds "$key" > "$credsPath"; then
      gen3_log_err "gen3_db_psql - unable to find creds for service $key"
      rm -rf "$credsPath"
      return 1
    fi
    database=$(jq -r ".db_database" < $credsPath)
  fi
  username=$(jq -r ".db_username" < $credsPath)
  password=$(jq -r ".db_password" < $credsPath)
  host=$(jq -r ".db_host" < $credsPath)
  shred "$credsPath"
  rm "$credsPath"

  #
  # Allow the client to override the database we connect to - 
  # useful in `gen3 reset` to connect to template1
  #
  local userdb
  userdb=false
  for arg in "$@"; do
    if [[ "$arg" = "-d" || "$arg" =~ "^--dbname" ]]; then
      userdb=true
    fi
  done
  if [[ "$userdb" = false ]]; then
    PGPASSWORD="$password" psql -U "$username" -h "$host" -d "$database" "$@"
  else
    PGPASSWORD="$password" psql -U "$username" -h "$host" "$@"
  fi
}


gen3_db_service_setup() {
  local service
  local server

  server=""
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_db_setup SERVICE [SERVER]"
    return 1
  fi

  service="$1"
  shift
  if [[ $# -gt 0 ]]; then
    server="$1"
    shift
  fi
  if [[ "$service" =~ ^server || (! $service =~ ^[a-z][a-z0-9_]{0,}$) ]]; then
    gen3_log_err "gen3_db_setup illegal service name: $service"
    return 1
  fi
  if [[ -n "$JENKINS_HOME" ]]; then
    gen3_log_err "gen3_db_setup NOOP in JENKINS"
    return 1
  fi
  if [[ ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "gen3_db_setup requires $(gen3_secrets_folder)/creds.json"
    return 1
  fi
  if gen3_db_service_creds "$service" > /dev/null 2>&1; then
    gen3_log_err "gen3_db_service_setup - db creds already exist for service $service"
    return 1
  fi
  if [[ -z "$server" ]]; then
    server="$(gen3_db_random_server)"
  fi
  if ! gen3_db_validate_server "$server"; then
    gen3_log_err "gen3_db_setup invalid server $server"
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
    echo "-" 
  done
}

# main -----------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  if [[ -z "$JENKINS_HOME" ]]; then
    gen3_db_init
  fi

  command="$1"
  shift
  case "$command" in
    "psql")
      gen3_db_psql "$@"
      ;;
    *)
      gen3_db_help
      ;;
  esac
fi
