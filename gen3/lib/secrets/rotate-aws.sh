#
# Support for rotating aws service account keys
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/bin/db"


#
# Generate a new key for the given service account,
# and output the json to stdout
#
gen3_secrets_aws_newkey() {
  local userName="$1"
  shift
  local result=1
  local outFile
  outFile="$(mktemp "$XDG_RUNTIME_DIR/awskey.json_XXXXXX")"
  if $(aws iam create-access-key "--user-name=$userName" >> $outFile) 1>&2; then
    cat "$outFile"
    result=$?
  fi
  /bin/rm "$outFile"
  return $result
}


#
# Garbage collect all but the newest keys for the given service account
#
gen3_secrets_aws_gc() {
  local userName="$1"
  shift
  local keyList
  keyList="$(aws iam list-access-keys --user-name "$userName")" || return 1
  local numKeys
  numKeys="$(jq -r '.AccessKeyMetadata | length' <<<"$keyList")"
  if [[ "$numKeys" -lt 2 ]]; then
    gen3_log_info "only $numKeys keys available - not garbage collecting"
    return 0
  fi
  key="$(jq -r .AccessKeyMetadata[0].AccessKeyId <<<"$keyList")"
  aws iam delete-access-key --user-name $userName --access-key-id $key 1>&2 || return 1
}

#
# Lists aws keys
#
gen3_secrets_aws_list() {
  local userName="$1"
  shift
  aws iam list-access-keys --user-name $userName
}


#
# Rotate the given key to a new key,
# and sync the secret onto the cluster
#
gen3_secrets_aws_rotate() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "aws_rotate takes username as an argument"
    return 1
  fi
  local userName="$1"
  gen3_log_info "garbage collecting old keys first (leaves current key in place)"
  gen3_secrets_aws_gc "$userName"
  gen3_log_info "generating a new key"
  local temp="$(mktemp "$XDG_RUNTIME_DIR/awsrotate.json_XXXXXX")"
  if ! (
    gen3_secrets_aws_newkey "$userName" > "$temp" \
    && cp "$temp" "$(gen3_secrets_folder)/$keyFile" \
    && rm "$temp"
  ); then
    rm "$temp"
    return 1
  fi
  gen3 secrets commit "rotate aws secret $keyFile"
  gen3_log_info "new key saved to disk (see git log)"
  gen3_log_info "to deploy to k8s: delete the old k8s secret, and kube-setup-fence to deploy the new secret"
  gen3_log_warn "the newest key before this script ran will be garbage collected on the next run ..."
}



#
# Dispatch aws secrets subcommands
#
gen3_secrets_aws() {
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "may only rotate creds from the admin vm"
    return 1
  fi
  local command
  if [[ $# -lt 1 ]]; then
    gen3_log_err "empty command name - use: gen3 secrets aws sub-command - see gen3 help secrets"
    return 1
  fi
  command="$1"
  shift
  case "$command" in
    "new-key")
      gen3_secrets_aws_newkey "$@"
      ;;
    "garbage-collect")
      gen3_secrets_aws_gc "$@"
      ;;
    "list")
      gen3_secrets_aws_list "$@"
      ;;
    "rotate")
      gen3_secrets_aws_rotate "$@"
      ;;
    *)
      gen3_log_err "unknown aws sub-command: $command"
      return 1
      ;;
  esac
}
