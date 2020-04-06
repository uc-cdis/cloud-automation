#
# Support for rotating postgres creds
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/bin/db"

#
# Revoke all permissions for the given user from the given database,
# then attempt to drop the user
#
gen3_secrets_revoke_postgres() {
  if [[ $# -lt 2 ]]; then
    gen3_log_err "revoke_user takes service and user, got: $@"
    return 1
  fi
  local service="$1"
  shift
  local username="$1"
  shift
  local creds
  if ! creds="$(gen3 db creds "$service")"; then
    gen3_log_err "unable to retrieve creds for service: $service"
    return 1
  fi
  local dbname="$(jq -r .db_database <<<"$creds")"
  local dbuser="$(jq -r .db_username <<<"$creds")"
  local server="$(jq -r .g3FarmServer <<<"$creds")"

  if [[ "$dbuser" == "$username" ]]; then
    gen3_log_err "refusing to revoke credentials from the active user $username for service $service"
    return 1
  fi
  local sqlList=(
        "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM \"$username\" CASCADE;"
        "REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM \"$username\" CASCADE;"
        "REVOKE ALL ON SCHEMA public FROM \"$username\" CASCADE;"
        "ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM \"$username\" CASCADE;"
        "ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM \"$username\" CASCADE;"
        "REVOKE ALL ON DATABASE \"$dbname\" FROM \"$username\" CASCADE;"
  );

  local connectAs
  local sqlCommand
  for connectAs in "$service"; do
    for sqlCommand in "${sqlList[@]}"; do
      gen3_log_info "$sqlCommand"
      gen3 db psql "$connectAs" -d "$dbname" -c "$sqlCommand" 1>&2
    done
  done
}

#
# Create a new user with ALL permissions on the given service's db
# Unfortunately - schema ALTERataions require a user to be a db owner,
# and we do not distinguish between a service user and an owner user.
#  https://www.postgresql.org/docs/9.1/sql-altertable.html
# We should migrate to setting up service and owner group roles, but
# that's a bigger project than I want to take on right now:
#   https://www.postgresqltutorial.com/postgresql-roles/
#
# @param service to roate
# @param dbname optional - defaults to service's current database - otherwise created dbname
# @return echo new creds block for db
#
gen3_secrets_rotate_pguser() {
  local server
  local service
  local username
  local dbname
  local password
  local creds
  local createdb=false

  gen3_log_warn "only use this command with new databases - see comment above"
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_secrets_rotate_pguser takes 1 arguments - service: $@"
    return 1
  fi
  service="$1"
  shift

  creds="$(gen3 db creds "$service")"
  if [[ $# -gt 0 ]]; then
    dbname="$1"
    createdb=true
    shift
    username="${dbname//-/_}_$(date -u +%Y%m%d_%H%M)"
    if [[ ! "$username" =~ ^$service ]]; then
      username="${service}_$username"  
    fi
    server="$(gen3_db_random_server)"
  else
    dbname="$(jq -r .db_database <<<"$creds")"
    username="${service}_$(gen3 db namespace)_$(date -u +%Y%m%d_%H%M)"
    server="$(jq -r .g3FarmServer <<<"$creds")"
  fi
  password="$(gen3 random)"

  if [[ "$createdb" == true ]]; then
    if ! gen3 db psql "$server" -c "CREATE DATABASE $dbname;" 1>&2; then
      gen3_log_err "Failed to create database $dbname"
      return 1
    fi
  fi
  if ! gen3 db psql "$server" -c "CREATE USER \"$username\" WITH PASSWORD '$password';" 1>&2; then
    gen3_log_err "gen3_db_service_setup" "CREATE USER $username failed"
    return 1
  fi
  #
  # on RDS - the root user is not really root, so GRANT the new user
  # permissions both as the current user and as the RDS-root
  #
  local sqlList=(
        "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"$username\" WITH GRANT OPTION;"
        "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"$username\" WITH GRANT OPTION;"
        "GRANT ALL ON SCHEMA public TO \"$username\" WITH GRANT OPTION;"
        "ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO \"$username\" WITH GRANT OPTION;"
        "ALTER DEFAULT PRIVILEGES GRANT ALL ON SEQUENCES TO \"$username\" WITH GRANT OPTION;"
        "GRANT ALL ON DATABASE \"$dbname\" TO \"$username\" WITH GRANT OPTION;"
  );

  local connectAs
  local sqlCommand
  for connectAs in "$server"; do
    for sqlCommand in "${sqlList[@]}"; do
      gen3_log_info "$sqlCommand"
      gen3 db psql "$connectAs" -d "$dbname" -c "$sqlCommand" 1>&2
    done
  done

  local newCreds
  if ! newCreds="$(jq -r --arg username "$username" --arg password "$password" --arg dbname "$dbname" '. | .db_username = $username | .db_password = $password | .db_database = $dbname | del(.g3FarmServer)' <<<"$creds")"; then
    gen3_log_err "failed to generate new creds"
    return 1
  fi
  echo "$newCreds"
}


#
# Rotate the password on the given service postgres user,
# and update the `Gen3Secrets/` accordingly.
#
gen3_secrets_update_pgpasswd() {
  local server
  local service
  local username
  local dbname
  local password
  local creds

  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_secrets_rotate_pguser takes 1 arguments - service: $@"
    return 1
  fi
  service="$1"
  shift
  creds="$(gen3 db creds "$service")"
  username="$(jq -r .db_username <<<"$creds")"
  dbname="$(jq -r .db_database <<<"$creds")"
  password="$(gen3 random)"
  server="$(jq -r .g3FarmServer <<<"$creds")"

  #
  # on RDS - the root user is not really root, so GRANT the new user
  # permissions both as the current user and as the RDS-root
  #
  local sqlList=(
      "ALTER USER \"$username\" WITH PASSWORD '$password';"
  );

  local promptUser="$(
    yesno=no
    gen3_log_warn "about to update db password for $username - proceed? (y/n)"
    read -r yesno
    echo "$yesno"
  )"

  if [[ ! $promptUser =~ ^y(es)?$ ]]; then
    return 1
  fi

  local connectAs
  local sqlCommand
  for connectAs in "$service"; do
    for sqlCommand in "${sqlList[@]}"; do
      gen3_log_info "$sqlCommand"
      gen3 db psql "$connectAs" -d "$dbname" -c "$sqlCommand" 1>&2
    done
  done

  local newCreds
  if ! newCreds="$(jq -r --arg password "$password" '. | .db_password = $password | del(.g3FarmServer)' <<<"$creds")"; then
    gen3_log_err "failed to generate new creds"
    return 1
  fi
  echo "$newCreds"
}


gen3_secrets_rotate_sheepdog() {
  gen3_log_info "generating new sheepdog db password"
  local newCreds

  if ! newCreds="$(gen3_secrets_update_pgpasswd sheepdog)"; then
    return 1
  fi
  local newCredsJson="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXXX")"
  jq -r --argjson sheepdog "$newCreds" '. | .sheepdog = $sheepdog' < "$(gen3_secrets_folder)/creds.json" > "$newCredsJson"
  cp "$newCredsJson" "$(gen3_secrets_folder)/creds.json"
  /bin/rm "$newCredsJson"
  gen3_log_info "creds.json updated - dbfarm may still reference the old password - update that password once the service is updated"
}

gen3_secrets_rotate_indexd() {
  gen3_log_info "generating new indexd db password"
  local newCreds

  if ! newCreds="$(gen3_secrets_update_pgpasswd indexd)"; then
    return 1
  fi
  local newCredsJson="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXXX")"
  jq -r --argjson indexd "$newCreds" '. | .indexd = $indexd' < "$(gen3_secrets_folder)/creds.json" > "$newCredsJson"
  cp "$newCredsJson" "$(gen3_secrets_folder)/creds.json"
  /bin/rm "$newCredsJson"
  gen3_log_info "creds.json updated - dbfarm may still reference the old password - update that password once the service is updated"
}


gen3_secrets_rotate_fence() {
  gen3_log_info "generating new fence db password"
  local newCreds

  if ! newCreds="$(gen3_secrets_update_pgpasswd fence)"; then
    return 1
  fi
  local newCredsJson="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXXX")"
  jq -r --argjson fence "$newCreds" '. | .fence = $fence' < "$(gen3_secrets_folder)/creds.json" > "$newCredsJson"
  cp "$newCredsJson" "$(gen3_secrets_folder)/creds.json"
  /bin/rm "$newCredsJson"

  local fenceYaml="$(gen3_secrets_folder)/apis_configs/fence-config.yaml"
  local dbuser
  local dbpassword
  local dbhost
  local dbdatabase
  if [[ -f "$fenceYaml" ]] && \
    dbuser="$(jq -r '.db_username' <<< "$newCreds")" && \
    dbpassword="$(jq -r '.db_password' <<< "$newCreds")" && \
    dbhost="$(jq -r '.db_host' <<< "$newCreds")" && \
    dbdatabase="$(jq -r '.db_database' <<< "$newCreds")"; then

    gen3_log_info "updating fence-config.yaml"
  else
    gen3_log_err "failed to process creds for fence-config"
    return 1
  fi
  local dblogin="postgresql://${dbuser}:${dbpassword}@${dbhost}:5432/${dbdatabase}"
  sed -i -E "s%^DB:.*$%DB: $dblogin%" "$fenceYaml"
  cp "$newFenceYaml" "$fenceYaml"
  gen3_log_info "creds.json and fence-config updated - dbfarm may still reference the old password - update that password after the service rolls to its new creds"
}

gen3_secrets_rotate_indexd_creds() {
  gen3_log_info "generating new indexd creds for fence and sheepdog"
  gen3_log_err "not yet implemented"
  return 1
}


#
# Generate a new password for the given
# postgres service or server, and update the appropriate
# secets on disk under Gen3Secrets/, but do not commit the changes -
# the caller should review the changes, run gen3 secrets sync,
# and rotate services as necessary.
#
gen3_secrets_rotate_postgres() {
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "may only rotate creds from the admin vm"
    return 1
  fi
  local service
  if [[ $# -lt 1 ]]; then
    gen3_log_err "empty service name - use: gen3 secrets rotate postgres service-name"
    return 1
  fi
  service="$1"
  shift
  case "$service" in
    "fence")
      gen3_secrets_rotate_fence
      ;;
    "indexd")
      gen3_secrets_rotate_indexd
      ;;
    "sheepdog")
      gen3_secrets_rotate_sheepdog
      ;;
    *)
      gen3_log_err "postgres password rotation not yet implemented for $service"
      return 1
      ;;
  esac
}
