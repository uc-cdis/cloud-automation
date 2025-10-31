#
# Support for rotating Google service account keys
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/bin/db"


#
# Little helper extracts client_email from first
# arg if it's the path to a json file, otherwise just echos first arg
#
gen3_secrets_gcp_email() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "must supply either a json key file or a service account id"
    return 1
  fi
  local key="$1"
  shift
  if [[ "$key" =~ \.json$ && -f "$key" ]]; then
    jq -e -r .client_email < "$key"
  else
    echo "$key"
  fi
}

#
# Generate a new key for the given service account,
# and output the json to stdout
#
gen3_secrets_gcp_newkey() {
  local email
  email="$(gen3_secrets_gcp_email "$@")" || return 1
  shift

  local result=1
  local outFile
  outFile="$(mktemp "$XDG_RUNTIME_DIR/gcpkey.json_XXXXXX")"
  if gcloud iam service-accounts keys create "$outFile" "--iam-account=$email" 1>&2; then
    cat "$outFile"
    result=$?
  fi
  /bin/rm "$outFile"
  return $result
}


#
# Garbage collect all but the newest keys for the given service account
#
gen3_secrets_gcp_gc() {
  local email
  email="$(gen3_secrets_gcp_email "$@")" || return 1
  shift
  local keyList
  keyList="$(gcloud iam service-accounts keys list --managed-by user --iam-account "$email" --format json --sort-by 'validAfterTime')" || return 1
  local numKeys
  numKeys="$(jq -r '. | length' <<<"$keyList")"
  if [[ "$numKeys" -lt 2 ]]; then
    gen3_log_info "only $numKeys keys available - not garbage collecting"
    return 0
  fi
  local it=0
  local kid
  for ((it=0; it < numKeys - 1; ++it)); do
    kid="$(jq -r --argjson it $it '.[$it].name' <<< "$keyList")" || return 1
    gen3_log_info "deleting $email key: $kid"
    gcloud iam service-accounts keys delete "$kid" --iam-account "$email" 1>&2 || return 1
  done
}

#
# Little helper to avoid remembering gcloud flags
#
gen3_secrets_gcp_list() {
  local email
  email="$(gen3_secrets_gcp_email "$@")" || return 1
  shift
  gcloud iam service-accounts keys list --managed-by user --iam-account "$email" --format json --sort-by 'validAfterTime'
}


#
# Rotate the given json key file to a new key,
# and sync the secret onto the cluster
#
# @param jsonKeyFile sub-path under $(gen3_secrets_folder) - ex: apis_configs/fence_google_app_creds_secret.json
#
gen3_secrets_gcp_rotate() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gcp_rotate takes service account json file as an argument"
    return 1
  fi
  local keyFile="$1"
  shift
  local email
  email="$(jq -e -r .client_email < "$(gen3_secrets_folder)/$keyFile")" || return 1
  gen3_log_info "garbage collecting old keys first (leaves current key in place)"
  gen3_secrets_gcp_gc "$email"
  gen3_log_info "generating a new key"
  local temp="$(mktemp "$XDG_RUNTIME_DIR/gcprotate.json_XXXXXX")"
  if ! (
    gen3_secrets_gcp_newkey "$email" > "$temp" \
    && cp "$temp" "$(gen3_secrets_folder)/$keyFile" \
    && rm "$temp"
  ); then
    rm "$temp"
    return 1
  fi
  gen3 secrets commit "rotate google secret $keyFile"
  gen3_log_info "new key saved to disk (see git log)"
  gen3_log_info "to deploy to k8s: delete the old k8s secret, and kube-setup-fence to deploy the new secret"
  gen3_log_warn "the newest key before this script ran will be garbage collected on the next run ..."
  gen3_log_warn "if this service account is linked to a gcloud configuration, then activate the new key with: gcloud auth activate-service-account $email --key-file '$(gen3_secrets_folder)/$keyFile'"
}



#
# Dispatch gcp secrets subcommands
#
gen3_secrets_gcp() {
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "may only rotate creds from the admin vm"
    return 1
  fi
  local command
  if [[ $# -lt 1 ]]; then
    gen3_log_err "empty command name - use: gen3 secrets gcp sub-command - see gen3 help secrets"
    return 1
  fi
  command="$1"
  shift
  case "$command" in
    "new-key")
      gen3_secrets_gcp_newkey "$@"
      ;;
    "garbage-collect")
      gen3_secrets_gcp_gc "$@"
      ;;
    "list")
      gen3_secrets_gcp_list "$@"
      ;;
    "rotate")
      gen3_secrets_gcp_rotate "$@"
      ;;
    *)
      gen3_log_err "unknown gcp sub-command: $command"
      return 1
      ;;
  esac
}
