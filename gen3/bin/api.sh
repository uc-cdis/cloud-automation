#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


gen3_api_help() {
  gen3 help api
}

gen3_access_token_to_cache() {
  local key="$1"
  if [[ -z "$key" ]]; then
    gen3_log_err "invalid token cache save key: $key"
    return 1
  fi
  local gen3CredsCache="${GEN3_CACHE_DIR}/${key}_access_token.json"
  tee "$gen3CredsCache"
}

#
# Return an access token from cache
#
gen3_access_token_from_cache() {
  local key="$1"
  if [[ -z "$key" ]]; then
    gen3_log_err "invalid token cache key: $key"
    return 1
  fi
  local gen3CredsCache="${GEN3_CACHE_DIR}/${key}_access_token.json"
  if [[ -f "$gen3CredsCache" ]]; then
    local expTime
    local nowTime
    nowTime=$(date '+%s')
    expTime=$(cat "$gen3CredsCache" | awk -F . '{ print $2 }' | base64 --decode 2> /dev/null | jq -r .exp)
    if [[ $((nowTime + 300)) -lt "$expTime" ]]; then # cache not out of date
      gen3_log_info "using cached token at $gen3CredsCache"
      cat $gen3CredsCache
      return $?
    fi
  fi
  return 1
}

#
# Generate a new access token - or pull from cache if available
#
gen3_access_token() {
  local username
  local exp
  username="$1"
  exp="$2"
  skip_cache=$3

  if [[ -z "$username" ]]; then
    gen3_api_help
    return 1
  fi
  if [[ -f "$username" ]]; then  # looks like an api-key
    gen3_access_token_from_apikey "$@"
    return $?
  fi

  if [[ -z "$exp" ]]; then
    exp=3600
  fi

  if [ "$skip_cache" != "true" ]; then
    gen3_access_token_from_cache "$username" && return 0
  fi
  g3kubectl exec -c fence $(gen3 pod fence) -- fence-create token-create --scopes openid,user,fence,data,credentials,google_service_account --type access_token --exp ${exp} --username ${username} | tail -1 | gen3_access_token_to_cache "$username"
}

#
# Little helper to make a new api key for a user
#
gen3_api_key() {
  local scopes
  local user
  user="$1"
  if ! shift; then
    gen3_log_err "gen3_api_key must specify user"
    return 1
  fi
  scopes="$(mktemp $XDG_RUNTIME_DIR/scopes.json_XXXXXX)"
  (cat - <<EOM
{
  "scope": [ "data", "user" ]
}
EOM
  ) > "$scopes"
  gen3 api curl user/credentials/cdis/ "$user" "$scopes"
  local resultCode=$?
  rm "$scopes"
  return "$resultCode"
}


#
# Try to retrieve an access token given an api key
#
gen3_access_token_from_apikey() {
  if [[ $# -lt 1 || ! -f "$1" ]]; then
    gen3_log_err "invalid api key: $1"
    exit 1
  fi
  apiKey="$1"
  shift
  local cacheKey
  cacheKey="$(realpath "$apiKey" | md5sum - | awk '{ print $1 }')"
  gen3_access_token_from_cache "$cacheKey" && return 0
  local url
  if ! url="$(jq -r .api_key < "$apiKey" | awk -F . '{ print $2 }' | base64 --decode 2> /dev/null | jq -r .iss)" \
    || [[ -z "$url" || ! "$url" =~ ^https://.+/user$ ]]; then
    gen3_log_err "failed to derive valid url from access token - got: $url"
    return 1
  fi
  url="${url}/credentials/cdis/access_token"
  curl -s -H 'Content-type: application/json' -X POST "$url" "-d@$apiKey" | jq -r .access_token | gen3_access_token_to_cache "$cacheKey"
}

#
# Little helper that acquires an access token
#
# @param path {string} below path
# @param user {string} to get access token for
# @param jsonFile {string} path to file to post - GET instead of POST if jsonFile is "",
# @param method can be set to DELETE
#
gen3_curl_json() {
  local path
  local userName
  local hostname
  local accessToken
  local jsonFile
  local method

  method="POST"
  jsonFile=""
  if [[ $# -lt 2 || -z "$1" ]]; then
    gen3_log_err "USE: gen3_curl_json path username jsonFile"
    return 1
  fi
  path="$1"
  shift
  userName="$1"
  shift
  if [[ $# -gt 0 ]]; then
    jsonFile="$1"
    shift
    if [[ ! -f "$jsonFile" ]]; then
      if [[ "$jsonFile" == "DELETE" ]]; then
        method="DELETE"
      else
        gen3_log_err "unable to read json file $jsonFile"
        return 1
      fi
    fi
  else
    method="GET"
  fi
  accessToken="$(gen3_access_token "$userName")"
  if [[ -z "$accessToken" ]]; then
    gen3_log_err "unable to acquire token for $userName"
    return 1
  fi
  if ! hostname="$(awk -F . '{ print $2 }' <<< "$accessToken" | base64 --decode 2> /dev/null | jq -r .iss | awk -F / '{ print $3 }')" \
    || [[ -z "$hostname" ]]; then
    gen3_log_err "unable to determine hostname for commons API"
    return 1
  fi
  local url="https://$hostname/$path"

  if [[ "$method" == "POST" ]]; then
    gen3_log_info "posting to $url"
    curl -s -X POST "$url" -H "Authorization: bearer $accessToken" -H "Content-Type: application/json" -H "Accept: aplication/json" "-d@$jsonFile"
  elif [[ "$method" == "DELETE" ]]; then
    gen3_log_info "deleting $url"
    curl -s -X DELETE "$url" -H "Authorization: bearer $accessToken" -H "Content-Type: application/json" -H "Accept: aplication/json"
  else
    gen3_log_info "getting $url"
    curl -s -X GET "$url" -H "Authorization: bearer $accessToken" -H "Accept: aplication/json"
  fi
  return $?
}


#
# Post a new project to the environment
#
# @param progName
# @parm projName
# @param userName
gen3_new_project() {
  local jsonFile
  local userName
  local projName
  local progName
  local result

  if [[ $# -lt 3 || -z "$1" || -z "$2" || -z "$3" ]]; then
    gen3_log_err "USE: gen3 api new-project prog-name proj-name username"
    return 1
  fi
  progName="$1"
  shift
  projName="$1"
  shift
  userName="$1"
  shift
  jsonFile="$(mktemp -p "$XDG_RUNTIME_DIR" proj.json_XXXXXX)"
  cat - > "$jsonFile" <<EOM
{
  "type": "project",
  "code": "$projName",
  "name": "$projName",
  "dbgap_accession_number": "$projName",
  "state": "open",
  "releasable": true
}
EOM
  gen3_curl_json "api/v0/submission/$progName" "$userName" "$jsonFile"
  result=$?
  rm $jsonFile
  return $result
}


#
# Post a new program to the environment
#
# @parm progName
# @param userName
#
gen3_new_program() {
  local jsonFile
  local userName
  local progName
  local result

  if [[ $# -lt 2 || -z "$1" || -z "$2" ]]; then
    gen3_log_err "USE: gen3 api new-program prog-name username"
    return 1
  fi
  progName="$1"
  shift
  userName="$1"
  shift
  jsonFile="$(mktemp -p "$XDG_RUNTIME_DIR" proj.json_XXXXXX)"
  cat - > "$jsonFile" <<EOM
{
  "name": "$progName",
  "type": "program",
  "dbgap_accession_number": "$progName"
}
EOM
  gen3_curl_json "api/v0/submission/" "$userName" "$jsonFile"
  result=$?
  rm $jsonFile
  return $result
}


gen3_indexd_post_folder_help() {
  cat - <<EOM
  gen3 indexd-post-folder [folder]:
      Post the .json files under the given folder to indexd
      in the current environment
      Note - currently only works with new records - does not
         attempt to update existing records.
EOM
  return 0
}

#
# Shortcut for querying manifest-global .data.hostname, with a cache
#
gen3_api_hostname() {
  g3k_hostname
}

#
# Shortcut for querying global .data.environment, with a cache
#
gen3_api_environment() {
  g3k_environment
}

#
# Alias - since gen3 db namespace is kind of a weird place to put that
#
gen3_api_namespace() {
  gen3 db namespace
}

#
# Generate a collision-safe name less than 64 characters 
# from the given base name.
# If no name is provided, then generate a random name.
#
gen3_api_safename() {
  local base="${1:-$(gen3 random)}"
  local env
  local namespace="$(gen3_api_namespace)"
  env="$(gen3_api_environment)" || return 1
  echo "${env}--${namespace}--${base}" | head -c63
}


gen3_indexd_post_folder() {
  local DEST_DOMAIN
  local DEST_DIR
  local INDEXD_USER
  local INDEXD_SECRET

  DATA_DIR="$1"

  if [[ -z "${DATA_DIR}" || "${DATA_DIR}" =~ ^-*h(elp)?$ ]]; then
    gen3_indexd_post_folder_help
    return 0
  fi

  if [[ ! -d "${DATA_DIR}" ]]; then
    gen3_log_err "DATA_DIR, ${DATA_DIR}, does not exist"
    gen3_indexd_post_folder_help
    return 1
  fi

  DEST_DOMAIN="$(gen3_api_hostname)"
  INDEXD_USER=gdcapi
  # grab the gdcapi indexd password from sheepdog creds
  INDEXD_SECRET="$(gen3 secrets decode sheepdog-creds creds.json | jq -r '.indexd_password')"

  ls -1f "${DATA_DIR}" | while read -r name; do 
    if [[ $name =~ .json$ ]]; then
      echo $name; 
      curl -i -u "${INDEXD_USER}:$INDEXD_SECRET" -H "Content-Type: application/json" -d @"$DATA_DIR/$name" "https://${DEST_DOMAIN}/index/index/"
      echo --------------------; 
      echo ---------------; 
    fi
  done
}

#
# Download all the indexd records from the given domain -
# manage the paging.
# Ex:
#    gen3 api indexd-download domain.commons.io data/
#
gen3_indexd_download_all() {
  local DOMAIN
  local DEST_DIR
  local INDEXD_USER
  local INDEXD_SECRET

  if [[ $# -lt 2 ]]; then
      gen3_log_err "gen3_indexd_download_all takes 2 arguments: domain and destintation folder"
      return 1
  fi
  DOMAIN="$1"
  shift
  DATA_DIR="${1%%/}"
  shift

  if [[ ! -d "${DATA_DIR}" ]]; then
    gen3_log_err "destination folder, ${DATA_DIR}, does not exist"
    return 1
  fi

  local stats
  local totalFiles=0
  local fetchUrl="https://${DOMAIN}/index/_stats"
  if ! stats="$(curl -s "$fetchUrl")" || ! totalFiles="$(jq -e -r .fileCount <<<"$stats")"; then
      gen3_log_err "Failed to retrieve https://${DOMAIN}/index/_stats"
      return 1
  fi
  gen3_log_info "Preparing to fetch $totalFiles from $DOMAIN to $DATA_DIR/ in batches of 1000"
  local count=0
  local start=""
  local dataFile
  while true; do
    fetchUrl="https://${DOMAIN}/index/index?limit=1000"
    dataFile="${DATA_DIR}/indexd_${DOMAIN//./_}_${count}.json"
    if [[ -n "$start" ]]; then
      fetchUrl="${fetchUrl}&start=$start"
    fi
    gen3_log_info "Fetching $fetchUrl into $dataFile"
    curl -s "$fetchUrl" > "$dataFile"
    start="$(jq -r '.records[-1].did' < "$dataFile")"
    count=$((count + 1))
    if [[ "$start" == null || $((count * 1000)) -gt "$totalFiles" ]]; then 
      break
    fi
    sleep 1
  done
}

gen3_indexd_delete() {
  local did="$1"
  if ! shift || [[ -z "$did" ]]; then
    gen3_log_err "invalid did: $did"
    return 1
  fi
  local INDEXD_USER=gdcapi
  local INDEXD_SECRET
  # grab the gdcapi indexd password from sheepdog creds
  INDEXD_SECRET="$(gen3 secrets decode sheepdog-creds creds.json | jq -r '.indexd_password')" || return 1
  local dest
  dest="$(gen3 api hostname)" || return 1
  local record
  record="$(curl -s "https://$dest/index/$did")"
  gen3_log_info "loaded https://$dest/index/$did : $record"
  if rev="$(jq -e -r .rev <<< "$record")"; then
    # record exists - need to delete it
    local deleteUrl="https://$dest/index/index/${did}?rev=$rev"
    gen3_log_info "DELETE to $deleteUrl"
    curl -s -u "$INDEXD_USER:$INDEXD_SECRET" -X DELETE "$deleteUrl" -H 'Content-Type: application/json'
  else
    gen3_log_err "unable to resolve revision for $did"
  fi
}


gen3_sower_template() {
  local name="$1"
  
  case "$name" in
    "pfb")
      cat - <<EOM
{
  "action": "export",
  "input": {
    "filter": {
      "AND": []
    }
  }
}
EOM
      ;;
    *)
      gen3_log_err "unknown template name: $name"
      return 1
      ;;
  esac
}

gen3_sower_run() {  
  local commandFile="$1"
  local apiKey="$2"
  if [[ $# -lt 2 ]]; then
    gen3_log_err "use: gen3_sower_run commandFile apiKey|username"
    return 1
  fi
  shift
  shift
  if [[ ! -f "$commandFile" ]] || ! jq -e -r . < "$commandFile" 1>&2; then
    gen3_log_err "sower command file does not exist or is not valid json: $commandFile"
    return 1
  fi

  local response
  if ! response="$(gen3 api curl "job/dispatch" "$apiKey" "$commandFile")"; then
    gen3_log_err "failed to submit sower command - $response"
    return 1
  fi
  gen3_log_info "got response: $response"
  local uid
  if ! uid="$(jq -e -r .uid <<< "$response")"; then
    gen3_log_err "failed to retrieve uid from response: $response"
    return 1
  fi
  local count=0
  local status=""
  while [[ "$count" -lt 100 ]]; do
      gen3_log_info "waiting for job with uid: $uid"
      sleep 10
      if ! response="$(gen3 api curl "job/status?UID=$uid" "$apiKey")"; then
        gen3_log_warn "failed status query - got response: $response"
      else
        gen3_log_info "got response: $response"
      fi
      status="$(jq -r .status <<< "$response")"
      gen3_log_info "got status: $status"
      if [[ "$status" != "Running" ]]; then count=100; fi
      count=$((count + 1))
  done
  gen3_log_info "fetching output for $uid"
  gen3 api curl "job/output?UID=$uid" "$apiKey"
}

#---------- main

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "indexd-download-all")
      gen3_indexd_download_all "$@"
      ;;
    "indexd-post-folder")
      gen3_indexd_post_folder "$@"
      ;;
    "indexd-delete")
      gen3_indexd_delete "$@"
      ;;
    "access-token")
      gen3_access_token "$@"
      ;;
    "api-key")
      gen3_api_key "$@"
      ;;
    "environment")
      gen3_api_environment "$@"
      ;;
    "hostname")
      gen3_api_hostname "$@"
      ;;
    "namespace")
      gen3_api_namespace "$@"
      ;;
    "new-program")
      gen3_new_program "$@"
      ;;
    "new-project")
      gen3_new_project "$@"
      ;;
    "sower-run")
      gen3_sower_run "$@"
      ;;
    "sower-template")
      gen3_sower_template "$@"
      ;;
    "curl")
      gen3_curl_json "$@"
      ;;
    "safe-name")
      gen3_api_safename "$@"
      ;;
    *)
      gen3_api_help
      ;;
  esac
fi
