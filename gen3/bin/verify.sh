#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


gen3_verify_bucket_manifest() {
  bucketName=$1
  protocol=$2
  if [[ $protocol != "s3" ]] || [[ $protocol != "gs" ]]; then
    gen3_log_err "Please select gs or s3 for your protocol"
    exit 1
  fi
  if [[ -z $3 ]]; then
    profile="default"
  else
    profile=$3
  fi
  bucketManifest=$(gen3 psql indexd -c "select url from index_record_url where url like '$protocol://$bucketName%';" | grep $protocol://)
  if [[ $protocol == "s3" ]]; then
    aws s3 ls --profile=$profile s3://$bucketName --recursive | awk '{print $4}' > $XDG_RUNTIME_DIR/objects_in_bucket
  else
     gsutil -u $profile ls gs://$bucketName/** > $XDG_RUNTIME_DIR/objects_in_bucket
  fi
  while read line; do
    filePath=$(echo $line | sed -e "s/^ $protocol:\/\/$bucketName\///")
    check=$(cat $XDG_RUNTIME_DIR/objects_in_bucket | grep "$filePath")
    if [[ -z $check ]]; then
      gen3_log_warn "$line not found" 
    fi
  done<<<"$bucketManifest"
}

gen3_verify_help() {
  gen3 help verify
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  command="$1"
  shift
  case "$command" in
    "bucket-manifest")
      gen3_verify_bucket_manifest "$@"
      ;;
    *)
      gen3_verify_help
      ;;
  esac
  exit $?
fi
