#
# Support for rotating Google service account keys
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/bin/db"


#
# Generate a new key for the given service account,
# and output the json to stdout
#
gen3_secrets_gcp_newkey() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gcp_newkey takes service account client_email as an argument"
    return 1
  fi
  local email="$1"
  shift
  email=csoc-adminvm@dcf-integration.iam.gserviceaccount.com
  gcloud iam service-accounts keys list --managed-by user --iam-account "$email"
}

#
# Garbage collect the all but the newest keys for the given service account
#
gen3_secrets_gcp_gc() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gcp_newkey takes service account client_email as an argument"
    return 1
  fi
  local email="$1"
  shift
}


#
# Rotate the given json key file to a new key,
# and sync the secret onto the cluster
#
# @param jsonKeyFile must be under $(gen3_secrets_folder)
#
gen3_secrets_gcp_rotate() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gcp_newkey takes service account client_email as an argument"
    return 1
  fi
  local email="$1"
  shift
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
    "rotate")
      gen3_secrets_gcp_rotate "$@"
      ;;
    *)
      gen3_log_err "unknown gcp sub-command: $command"
      return 1
      ;;
  esac
}
