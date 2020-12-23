#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ---------------------------

#
# Derive the S3 prefix for the dashboard bucket:
#    s3://bucket-name/hostname
#
gen3_board_prefix() {
  gen3 secrets decode dashboard-g3auto config.json | jq -e -r '"s3://" + .bucket + "/" + .prefix'
}

#
# Publish the given local file to the given subpath under 
# either the Public/ or Secure/ folder
#
# @param securityDomain set to "public" or "secure"
# @param localPath path to local file or directory
# @param destPath destination S3 path (under Public/ or Secure/ based on isPublic)
#
gen3_board_publish() {
  local prefix
  if ! prefix="$(gen3_board_prefix)"; then
    gen3_log_err "failed to acquire dashboard prefix info - is dashboard deployed?"
    return 1
  fi
  if [[ $# -lt 3 ]]; then
    gen3_log_err "use: gen3_board_publish isPublic localPath destPath"
    return 1
  fi
  local securityDomain="$1"
  shift
  local localPath="$1"
  shift
  local destPath="${1#/}" # no leading /
  shift

  if [[ "$securityDomain" == "public" ]]; then
    prefix="${prefix}/Public"
  elif [[ "$securityDomain" == "secure" ]]; then
    prefix="${prefix}/Secure"
  else
    gen3_log_err "unsupported security domain: $securityDomain"
    return 1
  fi
  if [[ ! -e "$localPath" ]]; then
    gen3_log_err "local file does not exist: $localPath"
    return 1
  fi
  if ! [[ "${destPath}" =~ ^[a-zA-Z0-9_\./-]+$ ]]; then
    gen3_log_err "invalid destination - characters allowed: [a-z0-9.A-Z_/-]: $destPath"
    return 1
  fi
  local fullPath="${prefix}/$(sed 's@///*@/@g' <<< "${destPath}")"
  local options=()
  if [[ -d "${localPath}" ]]; then
    options+=(--recursive)
  fi
  gen3_log_info "aws s3 cp ${localPath} ${fullPath} ${options[@]}"
  aws s3 cp "${localPath}" "${fullPath}" ${options[@]}
}

gen3_board_gitsync() {
  local folder="$(gen3 gitops folder)/dashboard"
  local it
  local prefix
  if ! prefix="$(gen3_board_prefix)"; then
    gen3_log_err "failed to acquire dashboard prefix info - is dashboard deployed?"
    return 1
  fi

  if [[ -d "${folder}/Public" ]]; then
    for it in "${folder}"/Public/*; do
      if [[ -e "$it" ]]; then
        gen3_board_publish public "$it" "${it##*/}"
      fi 
    done 
  fi
  if [[ -d "${folder}/Secure" ]]; then
    for it in "${folder}"/Secure/*; do
      if [[ -e "$it" ]]; then
        gen3_board_publish secure "$it" "${it##*/}"
      fi
    done 
  fi
}

gen3_board_main() {
  if [[ $# -lt 1 ]]; then
    gen3 "help" dashboard
    return 1
  fi
  local command="$1"
  shift
  case "$command" in
  "prefix")
    gen3_board_prefix "$@";
    ;;
  "publish")
    gen3_board_publish "$@"
    ;;
  "gitops-sync")
    gen3_board_gitsync "$@"
    ;;
  *)
    gen3_log_err "invalid command: $command"
    gen3 "help" dashboard
    return 1
    ;;
  esac
}

# main ---------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_board_main "$@"
fi
