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
    echo -e $(red_color "g3k_psql: No serviceName specified")
    return 1
  fi
  if [[ -z "$vpc_name" ]]; then
    echo -e $(red_color "g3k_psql: vpc_name variable must be set")
    return 1
  fi

  if [[ -f "${HOME}/${vpc_name}_output/creds.json" ]]; then # legacy path - fix it
    if [[ ! -f "${HOME}/${vpc_name}/creds.json" ]]; then
      # new path
      mkdir -p "${HOME}/${vpc_name}"
      cp "${HOME}/${vpc_name}_output/creds.json" "${HOME}/${vpc_name}/creds.json"
    fi
    mv "${HOME}/${vpc_name}_output/creds.json" "${HOME}/${vpc_name}_output/creds.json.bak"
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
    echo -e $(red_color "Invalid service: $serviceName")
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
  g3kubectl get secret "${key}-creds" -o json | jq -r '.data["creds.json"]' | base64 --decode > "$credsPath"
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
