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
  local force
  if [[ $# -lt 1 || -z "$1" ]]; then
    gen3_log_err "gen3_db_reset" "must specify serviceName"
    return 1
  fi

  serviceName="$1"
  if [[ "$serviceName" == "$peregrine" ]]; then
    gen3_log_err "gen3_db_reset" "may not reset peregrine - only sheepdog"
    return 1
  fi
  shift
  force=$1

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
  if [[ $force == "--force" ]]; then 
    gen3_log_warn "--force flag applied - Dropping all connections to the db before dropping"
    echo "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname='${dbname}' AND pid <> pg_backend_pid();" | gen3 psql "$serverName"
    result=$?
  fi
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
  gen3_db_psql "$serverName" -c "CREATE EXTENSION IF NOT EXISTS ltree;" --dbname "$dbname" || true
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
  jq -r --arg g3FarmServer "$server" '.g3FarmServer = $g3FarmServer | del(.fence_host) | del(.fence_username) | del(.fence_password) | del(.fence_database)' < "$tempResult"
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
  local info
  info="$(gen3_db_farm_json)" || return 1
  jq -r '. | keys | join("\n")' <<< "$info"
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
  local info
  info="$(gen3_db_farm_json)" || return 1
  jq -e -r --arg server "$server" '.[$server]' <<< "$info"
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
# Given a gen3 server name, determine the RDS instance id
#
gen3_db_server_rds_id() {
  local address
  local serverInfo

  if ! serverInfo="$(gen3_db_server_info "$@")"; then
    return 1
  fi
  local address
  if ! address="$(jq -e -r .db_host <<<"$serverInfo")"; then
    gen3_log_err "unable to determine address for $@"
    return 1
  fi
  aws rds describe-db-instances | jq -e -r --arg address "$address" '.DBInstances[] | select(.Endpoint.Address==$address) | .DBInstanceIdentifier'
}

#
# Take an RDS full server snapshot
#
# @param serverName
# @return echo snapshotId
#
gen3_db_snapshot_take() {
  local snapshotId
  local serverName
  local dryRun=false

  if [[ $# -gt 0 ]]; then
    serverName="$1"
    shift
  else
    gen3_log_err "no server specified"
    return 1
  fi
  if [[ "$1" =~ ^-*dry-?run ]]; then
    dryRun=true
  fi
  local instanceId
  if ! instanceId="$(gen3_db_server_rds_id "$serverName")"; then
    gen3_log_err "failed to find rds instance id for server: $serverName"
    return 1
  fi
  snapshotId="gen3-snapshot-${serverName}-$(date -u +%Y%m%d-%H%M%S)"
  if [[ "$dryRun" == true ]]; then
    gen3_log_info "dryrun mode - not taking snapshot"
  else
    aws rds create-db-snapshot --db-snapshot-identifier "$snapshotId" --db-instance-identifier "$instanceId"
  fi
}

#
# List the snapshots associated with a particular server
#
gen3_db_snapshot_list() {
  local serverName

  if [[ $# -gt 0 ]]; then
    serverName="$1"
    shift
  else
    gen3_log_err "no server specified"
    return 1
  fi
  local instanceId
  if ! instanceId="$(gen3_db_server_rds_id "$serverName")"; then
    gen3_log_err "failed to find rds instance id for server: $serverName"
    return 1
  fi
  aws rds describe-db-snapshots --db-instance-identifier "$instanceId"
}


#
# pg_dump the specified database to stdout
#
# @param serviceName to backup
# @return 0 on success, backup to stdout
#
gen3_db_backup() {
  local serviceName="$1"
  local creds
  local database
  local username
  local password
  local host
  
  if [[ -z "$serviceName" ]]; then
    gen3_log_err "serviceName not provided"
    return 1
  fi
  if ! creds="$(gen3_db_service_creds "$serviceName")"; then
    gen3_log_err "unable to find creds for service $serviceName"
    return 1
  fi

  database=$(jq -r ".db_database" <<< "$creds")
  username=$(jq -r ".db_username" <<< "$creds")
  password=$(jq -r ".db_password" <<< "$creds")
  host=$(jq -r ".db_host" <<< "$creds")
  PGPASSWORD="$password" pg_dump "--username=$username" "--dbname=$database" "--host=$host" --no-password --no-owner --no-privileges
}

#
# pg_restore to a database with the given name
#         on the given server
#
# @param serviceName to restore to
# @param backupFile to restore from
# @param --dryrun optional
# @return 0 on success
#
gen3_db_restore() {
  local serviceName
  local creds
  local database
  local username
  local password
  local host
  local backupFile
  
  if [[ $# -lt 2 ]]; then
    gen3_log_err "service and backupFile are required arguments"
    return 1
  fi
  serviceName="$1"
  shift
  if [[ -z "$serviceName" ]]; then
    gen3_log_err "serviceName not provided"
    return 1
  fi
  backupFile="$1"
  shift
  if [[ ! -f "$backupFile" ]]; then
    gen3_log_err "backup file does not exist: $backupFile"
    return 1
  fi

  local dryRun=false

  if [[ "$1" =~ ^-*dry-?run ]]; then
    dryRun=true
    shift
  fi

  if ! creds="$(gen3_db_service_creds "$serviceName")"; then
    gen3_log_err "unable to find creds for service $serviceName"
    return 1
  fi

  username=$(jq -r ".db_username" <<< "$creds")
  password=$(jq -r ".db_password" <<< "$creds")
  host=$(jq -r ".db_host" <<< "$creds")

  local serverUser
  local serverName
  # get the server root user
  serverName="$(jq -r .g3FarmServer <<<"$creds")"
  serverUser="$(gen3_db_server_info "$server" | jq -r .db_username)"
  if [[ -z "$serverName" || -z "serverUser" ]]; then
    gen3_log_err "failed to retrieve creds for server $host"
    return 1
  fi

  local dbname="$(echo ${serviceName}_$(gen3_db_namespace)_restore_$(date -u +%Y%m%d_%H%M%S) | tr - _)"
  if [[ "$dryRun" == false ]]; then
    gen3_log_info "creating database $dbname"
    # create the db as the root user, then grant permissions to the service user
    gen3 psql "$serverName" -c "CREATE DATABASE ${dbname};" 1>&2
    gen3 psql "$serverName" -c  "GRANT ALL ON DATABASE ${dbname} TO $username WITH GRANT OPTION;" 1>&2
    gen3_log_info "restoring $dbname from $backupFile"
    gen3 psql "$serviceName" -d "$dbname" -f "$backupFile" 1>&2
    jq -r --arg dbname "$dbname" '.db_database = $dbname' <<< "$creds"
  else
    gen3_log_info "dryRun not creating new database"
  fi
}

# Used to encrypt each db
gen3_db_encrypt() {
  # Need the account and profile used in gen3 workon to be able to setup terraform
  # Can optionally take the dump directory to define where to place the psql dumps. Useful for large databases where we want to store the dumps on an extra ebs volume
  local account=$1
  local profile=$2
  if [[ -z $3 ]]; then
    local dumpDir=$WORKSPACE
  else
    local dumpDir=$3
  fi
  # We want to get the security/parameter groups and subnets from the current rds so we can have it match the old ones
  local securityGroupId=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-fencedb"]}' | jq -r .DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId)
  local dbSubnet=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-fencedb"]}' | jq -r .DBInstances[0].DBSubnetGroup.DBSubnetGroupName)
  local dbParameterGroupName=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-fencedb"]}' | jq -r .DBInstances[0].DBParameterGroups[0].DBParameterGroupName)
  gen3_log_info "Taking snapshots. Please check that you have enough disk space and stop if disk space gets filled"
  gen3_log_info "If the databases are large consider mounting a new volume and adding a third parameter to this command to specify a different snapshot directory"

  gen3 db backup indexd  > $dumpDir/indexd-backup.sql
  gen3 db backup fence  > $dumpDir/fence-backup.sql
  gen3 db backup gdcapi  > $dumpDir/gdcapidb-backup.sql
  gen3 db backup arborist  > $dumpDir/arborist-backup.sql
  gen3 db backup metadata  > $dumpDir/metadata-backup.sql
  gen3 db backup wts  > $dumpDir/wts-backup.sql
  gen3 db backup requestor  > $dumpDir/requestor-backup.sql
  gen3 db backup audit  > $dumpDir/audit-backup.sql

  # Quick check to ensure the snapshots were taken successfully. Will prevent new db from getting incomplete data.
  echo "Did the snapshots get created correctly?(yes/no)"
  read snapshotBool

  if [[ $snapshotBool != "yes" ]]; then
    gen3_log_err "Snapshots were not indicated to be taken correctly. Please clean up the old ones and try again"
    gen3_log_err "If you ran out of space please setup a new volume and use the third parameter to this command to specify a different snapshot directory"
    exit 1
  fi

  # Switch to the main commons terraform to grab current config then create new terraform and use original config with added parameters
  gen3 workon $account $profile
  gen3 cd
  configFile=$(cat config.tfvars)
  gen3 workon $account "$profile"__encrypted-rds
  gen3 cd
  mv config.tfvars config.tfvars-backup
  echo "$configFile">>config.tfvars
  echo "security_group_local_id=\"$securityGroupId\"" >> config.tfvars
  echo "aws_db_subnet_group_name=\"$dbSubnet\"" >> config.tfvars
  echo "db_pg_name=\"$dbParameterGroupName\"" >> config.tfvars
  gen3 tfplan
  gen3 tfapply

  # Use sed to update all secrets, remove the arborist and metadata g3auto folders to recreate those db's then run kube-setup-secrets 
  local newFenceDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-encrypted-fencedb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local newIndexdDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-encrypted-indexddb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local newGdcApiDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-encrypted-gdcapidb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local originalFenceDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-fencedb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local originalIndexdDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-indexddb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local originalGdcApiDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-gdcapidb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  gen3_log_info "Updating fence db name from $originalFenceDbUrl to $newFenceDbUrl in $(gen3_secrets_folder)"
  grep -rl $originalFenceDbUrl "$(gen3_secrets_folder)" | xargs sed -i "s/$originalFenceDbUrl/$newFenceDbUrl/g"
  grep -rl $originalIndexdDbUrl "$(gen3_secrets_folder)" | xargs sed -i "s/$originalIndexdDbUrl/$newIndexdDbUrl/g"
  grep -rl $originalGdcApiDbUrl "$(gen3_secrets_folder)" | xargs sed -i "s/$originalGdcApiDbUrl/$newGdcApiDbUrl/g"

  gen3_log_info "Disabling gitops sync before updating secrets to ensure services not rolled during db setup"
  g3kubectl delete cronjob gitops-sync
  mv "$(gen3_secrets_folder)"/g3auto/arborist "$(gen3_secrets_folder)"/g3auto/arb-backup
  mv "$(gen3_secrets_folder)"/g3auto/metadata "$(gen3_secrets_folder)"/g3auto/mtdta-backup
  mv "$(gen3_secrets_folder)"/g3auto/wts "$(gen3_secrets_folder)"/g3auto/wts-backup
  mv "$(gen3_secrets_folder)"/g3auto/requestor "$(gen3_secrets_folder)"/g3auto/requestor-backup
  mv "$(gen3_secrets_folder)"/g3auto/audit "$(gen3_secrets_folder)"/g3auto/audit-backup
  gen3 kube-setup-secrets
  if [[ -d "$(gen3_secrets_folder)"/g3auto/arb-backup ]]; then
    g3kubectl delete secret arborist-g3auto
    gen3 db setup arborist
  fi
  if [[ -d "$(gen3_secrets_folder)"/g3auto/mtdta-backup ]]; then
    g3kubectl delete secret metadata-g3auto
    gen3 db setup metadata
  fi
  if [[ -d "$(gen3_secrets_folder)"/g3auto/wts-backup ]]; then
    g3kubectl delete secret wts-g3auto
    gen3 db setup wts
  fi
  if [[ -d "$(gen3_secrets_folder)"/g3auto/requestor-backup ]]; then
    g3kubectl delete secret requestor-g3auto
    gen3 db setup requestor
  fi
  if [[ -d "$(gen3_secrets_folder)"/g3auto/audit-backup ]]; then
    g3kubectl delete secret audit-g3auto
    gen3 db setup audit
  fi
  gen3_log_info "restoring indexd db"
  gen3_db_reset "indexd"
  gen3 psql indexd  < $dumpDir/indexd-backup.sql
  gen3_log_info "restoring fence db"
  gen3_db_reset "fence"
  gen3 psql fence  <  $dumpDir/fence-backup.sql
  gen3_log_info "restoring sheepdog db"
  gen3_db_reset "sheepdog"
  gen3 psql gdcapi  < $dumpDir/gdcapidb-backup.sql
  gen3_log_info "restoring arborist db"
  gen3_db_reset "arborist"
  gen3 psql arborist  < $dumpDir/arborist-backup.sql
  gen3_log_info "restoring metadata db"
  gen3_db_reset "metadata"
  gen3 psql metadata  < $dumpDir/metadata-backup.sql
  gen3_log_info "restoring wts db"
  gen3_db_reset "wts"
  gen3 psql wts  < $dumpDir/wts-backup.sql
  gen3_log_info "restoring requestor db"
  gen3_db_reset "requestor"
  gen3 psql requestor  < $dumpDir/requestor-backup.sql
  gen3_log_info "restoring audit db"
  gen3_db_reset "audit"
  gen3 psql audit  < $dumpDir/audit-backup.sql


  # dbs are now working but we should update the terraform state to ensure db's can still be managed through the main commons terraform
  gen3 workon $account $profile
  gen3 cd
  gen3 tform state rm aws_db_instance.db_gdcapi
  gen3 tform import --config ~/cloud-automation/tf_files/aws/commons aws_db_instance.db_gdcapi  $vpc_name-encrypted-gdcapidb
  gen3 tform state rm aws_db_instance.db_fence
  gen3 tform import --config ~/cloud-automation/tf_files/aws/commons aws_db_instance.db_fence  $vpc_name-encrypted-fencedb
  gen3 tform state rm aws_db_instance.db_indexd
  gen3 tform import --config ~/cloud-automation/tf_files/aws/commons aws_db_instance.db_indexd  $vpc_name-encrypted-indexddb

  echo "Would you like to re-enable gitops-sync?(yes/no)"
  read gitopsBool
  if [[ $gitopsBool != "yes" ]]; then
    gen3_log_info "Gitops-sync not re-enabled"
    exit 0
  else
    gen3 job cron gitops-sync '*/5 * * * *'
    gen3_log_info "Gitops-sync re-enabled"
    exit 0
  fi
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

gen3_db_upgrade() {
  # Need the account and profile used in gen3 workon to be able to setup terraform, as well as the version to upgrade to
  local account=$1
  local profile=$2
  local version=$3
  local credsFile=$(cat $(gen3_secrets_folder)/creds.json)
  # Get the old db information
  local originalFenceDbUrl=$(echo $credsFile | jq -r .fence.db_host)
  local originalIndexdDbUrl=$(echo $credsFile | jq -r .indexd.db_host)
  local originalGdcApiDbUrl=$(echo $credsFile | jq -r .sheepdog.db_host)
  local originalFenceDb=$(echo $credsFile | jq -r .fence.db_host | cut -d '.' -f 1)
  local originalIndexdDb=$(echo $credsFile | jq -r .indexd.db_host | cut -d '.' -f 1)
  local originalGdcApiDb=$(echo $credsFile | jq -r .sheepdog.db_host | cut -d '.' -f 1)
  # Get the info to make sure new db are in same subnet with same groups
  local securityGroupId=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$originalFenceDb'"]}' | jq -r .DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId)
  local dbSubnet=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$originalFenceDb'"]}' | jq -r .DBInstances[0].DBSubnetGroup.DBSubnetGroupName)
  local dbParameterGroupName=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$originalFenceDb'"]}' | jq -r .DBInstances[0].DBParameterGroups[0].DBParameterGroupName)
  # Create snapshots of old db's asap, so that can complete while we work on terraform
  gen3_log_info "Creating db snapshots"
  aws rds create-db-snapshot --db-snapshot-identifier fence-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d) --db-instance-identifier $originalFenceDb
  aws rds create-db-snapshot --db-snapshot-identifier indexd-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d) --db-instance-identifier $originalIndexdDb
  aws rds create-db-snapshot --db-snapshot-identifier gdcapi-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d) --db-instance-identifier $originalGdcApiDb
  # Workon old module so we can grab the config.tfvars from it
  gen3 workon $account $profile
  gen3 cd
  configFile=$(cat config.tfvars)
  # Workon new encrypted db module to standup new db's under it
  gen3 workon $account $profile-psql-upgrade-$(date -u +%Y%m%d)__encrypted-rds
  gen3 cd
  # Copy the old config.tfvars, so that we can have consistent info for new db's
  mv config.tfvars config.tfvars-backup
  echo "$configFile">>config.tfvars2
  # Remove some potential fields from the config files, so that we can override them
  sed '/_snapshot/d' ./config.tfvars2  > config.tfvars
  sed '/_engine_version/d' ./config.tfvars > config.tfvars2
  local vpc=$(cat config.tfvars | grep vpc_name | cut -d '"' -f 2)
  sed '/vpc_name/d' ./config.tfvars2 > config.tfvars
  rm config.tfvars2
  # Add some variables to the config.tfvars file
  echo "vpc_name = \"$vpc-psql$(echo $version| cut -d '.' -f 1)\"" >> config.tfvars
  echo "security_group_local_id=\"$securityGroupId\"" >> config.tfvars
  echo "aws_db_subnet_group_name=\"$dbSubnet\"" >> config.tfvars
  echo "fence_snapshot = \"fence-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d)\"" >> config.tfvars
  echo "indexd_snapshot = \"indexd-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d)\"" >> config.tfvars
  echo "gdcapi_snapshot = \"gdcapi-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d)\"" >> config.tfvars
  echo "fence_engine_version = \"$version\"" >> config.tfvars
  echo "indexd_engine_version = \"$version\"" >> config.tfvars
  echo "sheepdog_engine_version = \"$version\"" >> config.tfvars
  # Wait for the snapshots to finish being taken
  while [[ "$(aws rds describe-db-snapshots --db-snapshot-identifier fence-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d) | jq -r .DBSnapshots[0].Status)" != "available" ]] && [[ "$(aws rds describe-db-snapshots --db-snapshot-identifier indexd-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d) | jq -r .DBSnapshots[0].Status)" != "available" ]] && [[ "$(aws rds describe-db-snapshots --db-snapshot-identifier gdcapi-psql-upgrade-snapshot-$2-$(date -u +%Y%m%d) | jq -r .DBSnapshots[0].Status)" != "available" ]]; do
    gen3_log_info "Waiting for snapshots to become ready"
    sleep 60
  done
  gen3_log_info "Snapshots ready, standing up new databases using the new snapshots"
  # Put in an extra sleep becuase somtimes snapshots are not fully ready when they say they are and tf will fail
  sleep 180
  # Stand up the new db's
  gen3 tfplan
  gen3 tfapply
  gen3_log_info "New databases ready, updating secrets to point to new db's, run kube-setup-secrets and roll everything when things looks ready"
  local newFenceDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-psql'$(echo $version| cut -d '.' -f 1)'-encrypted-fencedb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local newIndexdDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-psql'$(echo $version| cut -d '.' -f 1)'-encrypted-indexddb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  local newGdcApiDbUrl=$(aws rds describe-db-instances --filters '{"Name": "db-instance-id", "Values": ["'$vpc_name'-psql'$(echo $version| cut -d '.' -f 1)'-encrypted-gdcapidb"]}' | jq -r .DBInstances[0].Endpoint.Address)
  # Update the secrets folder with the new hostname
  grep -rl $originalFenceDbUrl "$(gen3_secrets_folder)" | xargs sed -i "s/$originalFenceDbUrl/$newFenceDbUrl/g"
  grep -rl $originalIndexdDbUrl "$(gen3_secrets_folder)" | xargs sed -i "s/$originalIndexdDbUrl/$newIndexdDbUrl/g"
  grep -rl $originalGdcApiDbUrl "$(gen3_secrets_folder)" | xargs sed -i "s/$originalGdcApiDbUrl/$newGdcApiDbUrl/g"

  # dbs are now working but we should update the terraform state to ensure db's can still be managed through the main commons terraform
  gen3 workon $account $profile
  gen3 cd
  gen3 tform state rm aws_db_instance.db_gdcapi
  gen3 tform import --config ~/cloud-automation/tf_files/aws/commons aws_db_instance.db_gdcapi  $vpc-psql$(echo $version| cut -d '.' -f 1)-encrypted-gdcapidb
  gen3 tform state rm aws_db_instance.db_fence
  gen3 tform import --config ~/cloud-automation/tf_files/aws/commons aws_db_instance.db_fence  $vpc-psql$(echo $version| cut -d '.' -f 1)-encrypted-fencedb
  gen3 tform state rm aws_db_instance.db_indexd
  gen3 tform import --config ~/cloud-automation/tf_files/aws/commons aws_db_instance.db_indexd  $vpc-psql$(echo $version| cut -d '.' -f 1)-encrypted-indexddb
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
    "backup")
      gen3_db_backup "$@"
      ;;
    "creds")
      gen3_db_service_creds "$@";
      ;;
    "encrypt")
      gen3_db_encrypt "$@";
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
    "restore")
      gen3_db_restore "$@"
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
    "snapshot")
      if [[ "$1" == "list" ]]; then
        shift
        gen3_db_snapshot_list "$@"
      elif [[ "$1" == "take" ]]; then
        shift
        gen3_db_snapshot_take "$@"
      else
        gen3_db_help
        exit 1
      fi
      ;;
    "upgrade")
      gen3_db_upgrade "$@"
      ;;
    *)
      gen3_db_help
      ;;
  esac
  exit $?
fi
