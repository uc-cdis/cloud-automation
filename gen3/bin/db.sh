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
# Cat the dbfarm k8s secret file if available - otherwise cat the secret
#
gen3_db_farm_json() {
  gen3 secrets decode dbfarm-g3auto servers.json
}

#
# Little helper for `gen3 reset` that will drop and re-create
# a database for a particular service.
# This method prompts an interactive user for approval
# before executing the reset unless given a 2nd argument "noprompt"
#
# @param serviceName
# @param [optional]noPrompt
#
gen3_db_reset() {
  local serviceName
  if [[ $# -lt 1 || -z "$1" ]]; then
    gen3_log_err "gen3_db_reset" "must specify serviceName"
    return 1
  fi

  serviceName="$1"
  if [[ "$serviceName" == "$peregrine" ]]; then
    gen3_log_err "gen3_db_reset" "may not reset peregrine - only sheepdog"
    return 1
  fi

  # connect as the admin user for the db server associated with the service
  local credsTemp="$(mktemp "$XDG_RUNTIME_DIR/credsTemp.json_XXXXXX")"
  if ! gen3_db_service_creds "$serviceName" > "$credsTemp"; then
    gen3_log_err "failed to retrieve db creds for service $serviceName"
    return 1
  fi
  local dbhost="$(jq -r .db_host < "$credsTemp")"
  local username="$(jq -r .db_username < "$credsTemp")"
  local dbname="$(jq -r ".db_database" < "$credsTemp")"
  rm "$credsTemp"
  if [[ -z "$dbhost" || -z "$dbname" || -z "$username" ]]; then
    gen3_log_err "failed to establish db credentials for service $serviceName"
    return 1
  fi

  local serverName
  # got the server host and db associated with this service - get the server root user
  serverName=$(gen3_db_farm_json | jq -e -r ". | to_entries | map(select(.value.db_host==\"$dbhost\")) | .[0].key"); 
  if [[ -z "$serverName" ]]; then
    gen3_log_err "failed to retrieve creds for server $dbhost"
    return 1
  fi

  # check for user consent before deleting and recreating tables
  local promptUser
  promptUser="$(
    yesno=no
    gen3_log_warn "about to drop the $dbname database for $serviceName from the $serverName postgres server - proceed? (y/n)"
    read -r yesno
    echo "$yesno"
  )"

  if [[ ! $promptUser =~ ^y(es)?$ ]]; then
    return 1
  fi

  local result
  echo "DROP DATABASE \"${dbname}\"; CREATE DATABASE \"${dbname}\"; GRANT ALL ON DATABASE \"$dbname\" TO \"$username\" WITH GRANT OPTION;" | gen3 psql "$serverName"
  result=$?
  if [[ "$serviceName" == "sheepdog" ]]; then 
    # special case - peregrine shares the database
    # Make sure peregrine has permission to read the sheepdog db tables
    gen3_log_info "gen3_db_reset" "granting db access permissions to peregrine"
    local peregrine_db_user;
    peregrine_db_user="$(g3kubectl get secrets peregrine-creds -o json | jq -r '.data["creds.json"]' | base64 --decode | jq -r  .db_username)"
    if [[ -n "$peregrine_db_user" ]]; then
      gen3 psql sheepdog -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $peregrine_db_user; ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO $peregrine_db_user;"
    else
      gen3_log_warn "gen3_db_reset" "unable to determine peregrine db username"
    fi
  fi

  #
  # install ltree extension (currently arborist requires this)
  # this will fail if the extension is already installed, so ignore that
  #
  gen3_db_psql "$server" -c "CREATE EXTENSION IF NOT EXISTS ltree;" --dbname "$dbname" || true
  return $result
}


#
# Bootstrap the db/servers.json secret
#
gen3_db_init() {
  local secretPath
  
  secretPath="$(gen3_secrets_folder)/g3auto/dbfarm/servers.json"
  if [[ (! -f "$secretPath") && -z "$JENKINS_HOME" && -d "$(gen3_secrets_folder)" ]]; then
    mkdir -p -m 0700 "$(dirname $secretPath)"
    # initialize the dbfarm with info for the fence, indexd, and sheepdog db servers
    if ! gen3 secrets decode dbfarm-g3auto servers.json > /dev/null 2>&1; then
      # create a new server list
          (cat - <<EOM
{
  "server1": $(gen3_db_service_creds fence | jq -r '.farmEnabled=true'),
  "server2": $(gen3_db_service_creds indexd | jq -r '.farmEnabled=true'),
  "server3": $(gen3_db_service_creds sheepdog | jq -r '.farmEnabled=false')
}
EOM
      ) | jq -r . > "$secretPath"
    else
      # sync k8s secret into Secrets/ folder
      gen3 secrets decode dbfarm-g3auto servers.json > "$secretPath"
    fi
    gen3 secrets sync "initialize dbfarm secret" 1>&2
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
  local dbcredsPath
  local tempResult
  credsPath="$(gen3_secrets_folder)/creds.json"
  dbcredsPath="$(gen3_secrets_folder)/g3auto/${key}/dbcreds.json"
  tempResult="$(mktemp "$XDG_RUNTIME_DIR/tempCreds.json_XXXXXX")"
  if [[ -z "$key" ]]; then
    gen3_log_err "gen3_db_service_creds: No serviceName specified"
    return 1
  fi
  
  if g3kubectl get secret "${key}-creds" > /dev/null 2>&1; then
    # prefer to pull creds from secret
    g3kubectl get secret "${key}-creds" -o json | jq -r '.data["creds.json"]' | base64 --decode > "$tempResult"
  elif g3kubectl get secret "${key}-g3auto" > /dev/null 2>&1 && g3kubectl get secret "${key}-g3auto" -ojson | jq -e -r '.data["dbcreds.json"]' > /dev/null 2>&1; then
    # prefer to pull creds from secret
    g3kubectl get secret "${key}-g3auto" -o json | jq -r '.data["dbcreds.json"]' | base64 --decode > "$tempResult"
  elif [[ -z "$JENKINS_HOME" && -f "$dbcredsPath" ]]; then
    cat "$dbcredsPath" > "$tempResult"
  elif [[ -z "$JENKINS_HOME" && -f "$credsPath" ]] && (jq -e -r ".[\"$key\"]" < "$credsPath" > "$tempResult"); then
    true
  else
    gen3_log_err "gen3_db_service_creds - unable to find ${key}-creds k8s secret or creds.json"
    rm "$tempResult"
    return 1
  fi
  local dbHost
  local server
  dbHost="$(jq -r .db_host < "$tempResult")"
  server="$(gen3_db_farm_json | jq -r --arg dbHost "$dbHost" '. | to_entries | map(select(.value.db_host==$dbHost)) | map(.key) | .[]')"
  jq -r --arg g3FarmServer "$server" '.g3FarmServer = $g3FarmServer' < "$tempResult"
  rm "$tempResult"
  return 0
}

#
# Select a random server that is farmEnabled
#
gen3_db_random_server() {
  local total
  local index
  local result
  local farmServersTemp
  farmServersTemp="$(mktemp "$XDG_RUNTIME_DIR/farmServers.json_XXXXXX")"
  gen3_db_farm_json | jq -r '. | to_entries | map(select(.value.farmEnabled==true)) | from_entries' > "$farmServersTemp"
  total="$(jq -r '. | keys | length' < "$farmServersTemp")"
  index=$((RANDOM % total))
  jq -r ". | keys | .[$index]" < "$farmServersTemp"
  result=$?
  rm "$farmServersTemp"
  return $result
}


#
# List the servers - one per line
#
gen3_db_server_list() {
  gen3_db_farm_json | jq -r '. | keys | join("\n")'
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
  gen3_db_farm_json | jq -e -r ".[\"$server\"]"
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
  gen3_db_psql "$server" --list | awk -F '|' '{ gsub(/ /, "", $1); if($1 != ""){ print $1 } }' | tail -n +4 | head -n -1
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
  gen3_db_psql "$server" -c 'SELECT u.usename FROM pg_catalog.pg_user u' | awk -F '|' '{ gsub(/ /, "", $1); if($1 != ""){ print $1 } }' | tail -n +3 | head -n -1
}

#
# List all the services with databases, so `gen3 db creds $service` or `gen3 db psql $service` works ...
#
gen3_db_service_list() {
  cat - <<EOM
fence
indexd
sheepdog
peregrine
EOM
  g3kubectl get secrets -o json | jq -r '.items | map(select( .data["dbcreds.json"] and (.metadata.name|test("-g3auto$")))) | map(.metadata.name | gsub("-g3auto$";"")) | .[]'

}

#
# Open a psql connection to the specified database service
# using that service credentials.  Respects psql overrides
# for '-d' and '-U'
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
  local userUser
  userdb=false
  userUser=false
  for arg in "$@"; do
    if [[ "$arg" = "-d" || "$arg" =~ "^--dbname" ]]; then
      userdb=true
    elif [[ "$arg" = "-U" || "$arg" =~ "^--username" ]]; then
      userUser=true
    fi
  done
  local extraArgs=("-h" "$host")
  if [[ "false" == "$userUser" ]]; then
    extraArgs+=( "-U" "$username")
  fi
  if [[ "false" == "$userdb" ]]; then
    extraArgs+=("-d" "$database")
  fi
  
  PGPASSWORD="$password" psql "${extraArgs[@]}" "$@"
}

#
# Scope user and db names to namespace
#
gen3_db_namespace() {
  local ctx
  local ctxNamespace
  local result

  if [[ -n "${KUBECTL_NAMESPACE}" ]]; then
    result="$KUBECTL_NAMESPACE"
  elif ctx="$(g3kubectl config current-context 2> /dev/null)"; then
    ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"
    if [[ -n "${ctxNamespace}" && "${ctxNamespace}" != null ]]; then
      result="$ctxNamespace"
    else
      result="default"
    fi
  else
    # running in a cron job or some similar environment
    result="default"
  fi
  echo "$result"
}

#
# Create a new database (user, secret, ...) for a service
#
# @param service name of the service
# @param server optional - defaults to random server
#
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
  local password
  local it
  
  namespace="$(gen3_db_namespace)"
  dbname="${service}_${namespace}"
  username="${service}_${namespace}"
  password="$(random_alphanumeric)"

  for it in $(gen3_db_list "$server"); do
    if [[ "$it" == "$dbname" ]]; then
      gen3_log_err "gen3_db_service_setup" "$dbname database already exists on server $it"
      return 1
    fi
  done
  for it in $(gen3_db_user_list "$server"); do
    if [[ "$it" == "$username" ]]; then
      gen3_log_err "gen3_db_service_setup" "$username user already exists on server $it"
      return 1
    fi
  done
  if ! gen3_db_psql "$server" -c "CREATE DATABASE \"${dbname}\";"; then
    gen3_log_err "gen3_db_service_setup" "CREATE DATABASE $dbname failed"
    return 1
  fi
  if ! gen3_db_psql "$server" -c "CREATE USER \"$username\" WITH PASSWORD '$password'; GRANT ALL ON DATABASE \"$dbname\" TO \"$username\" WITH GRANT OPTION;"; then
    gen3_log_err "gen3_db_service_setup" "CREATE USER $username failed"
    # try to clean up
    gen3_db_psql "$server" -c "DROP DATABASE \"${dbname}\";"
    return 1
  fi

  #
  # install ltree extension (currently arborist requires this)
  # this will fail if the extension is already installed, so ignore that
  #
  gen3_db_psql "$server" -c "CREATE EXTENSION IF NOT EXISTS ltree;" --dbname "$dbname" || true

  # Update creds.json, and generate secrets
  local dbhost
  dbhost="$(gen3_db_server_info "$server" | jq -r .db_host)"
  mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/$service"
  cat - > "$(gen3_secrets_folder)/g3auto/$service/dbcreds.json" <<EOM
{
  "db_host": "$dbhost",
  "db_username": "$username",
  "db_password": "$password",
  "db_database": "$dbname"
}
EOM
  gen3 secrets sync "setup new g3auto database - $dbname"
  return $?
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
    "creds")
      gen3_db_service_creds "$@";
      ;;
    "list")
      gen3_db_list "$@"
      ;;
    "namespace") #simplify testing
      gen3_db_namespace
      ;;
    "psql")
      gen3_db_psql "$@"
      ;;
    "reset")
      gen3_db_reset "$@"
      ;;
    "server")
      if [[ "$1" == "list" ]]; then
        shift
        gen3_db_server_list "$@"
      elif [[ "$1" == "info" ]]; then
        shift
        gen3_db_server_info "$@"
      else
        gen3_db_help
        exit 1
      fi
      ;;
    "services")
      gen3_db_service_list "$@"
      ;;
    "setup")
      gen3_db_service_setup "$@"
      ;;
    *)
      gen3_db_help
      ;;
  esac
  exit $?
fi
