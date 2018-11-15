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

  local credsPath="${HOME}/${vpc_name}/creds.json"

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
  credsPath="$(mktemp "${XDG_RUNTIME_DIR}/creds.json.XXXXXX")"
  g3kubectl get secret "${key}-creds" -o json | jq -r '.data["creds.json"]' | base64 --decode > "$credsPath"
  local username=$(jq -r ".db_username" < $credsPath)
  local password=$(jq -r ".db_password" < $credsPath)
  local host=$(jq -r ".db_host" < $credsPath)
  local database=$(jq -r ".db_database" < $credsPath)
  rm "$credsPath"
  PGPASSWORD="$password" psql -U "$username" -h "$host" -d "$database" "$@"
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  g3k_psql "$@"
fi
