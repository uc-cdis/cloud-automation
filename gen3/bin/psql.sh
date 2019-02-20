source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/g3k_manifest"


#
# Open a psql connection to the specified database
#
# @param serviceName should be one of indexd, fence, sheepdog
#
g3k_psql() {
  local serviceName=$1
  shift
  local key="${serviceName}"
  
  if [[ -z "$serviceName" ]]; then
    gen3_log_err "g3k_psql: No serviceName specified"
    return 1
  fi

  case "$serviceName" in
  "sheepdog")
    key=sheepdog
    ;;
  "peregrine")
    key=peregrine
    ;;
  "indexd")
    key=indexd
    ;;
  "fence")
    key=fence
    ;;
  *)
    gen3_log_err "Invalid service: $serviceName"
    return 1
    ;;
  esac

  local credsPath
  local username
  local password
  local host
  local database
  local arg
  credsPath="$(mktemp "${XDG_RUNTIME_DIR}/creds.json.XXXXXX")"
  
  if g3kubectl get secret "${key}-creds" > /dev/null 2>&1; then
    # prefer to pull creds from secret
    g3kubectl get secret "${key}-creds" -o json | jq -r '.data["creds.json"]' | base64 --decode > "$credsPath"
  elif [[ -f "$(gen3_secrets_folder)/creds.json" ]]; then
    jq -r ".${key}" < "$(gen3_secrets_folder)/creds.json" > "$credsPath"
  else
    gen3_log_err "unable to find ${key}-creds k8s secret or creds.json"
    return 1
  fi

  username=$(jq -r ".db_username" < $credsPath)
  password=$(jq -r ".db_password" < $credsPath)
  host=$(jq -r ".db_host" < $credsPath)
  database=$(jq -r ".db_database" < $credsPath)
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

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  g3k_psql "$@"
fi
