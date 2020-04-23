#!/bin/bash


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#
# Some helpers for generating bucket manifest
# on each of a set of db servers.
#

# lib -----------------------------------

# Creates
gen3_create_manifest() {
  local bucket=$1
  local destination=$2
  if [[ -f $WORKSPACE/tempKeyFile ]]; then
    gen3_log_info "previous key file found. Deleting"
    rm $WORKSPACE/tempKeyFile
  fi
  aws s3api list-objects --bucket "$bucket" --query 'Contents[].{Key: Key}' | jq -r '.[].Key' >> "$WORKSPACE/tempKeyFile"
  if [[ -f $WORKSPACE/manifest.csv ]]; then
    rm $WORKSPACE/manifest.csv
  fi
  while read line; do
    echo "$bucket,$line" >> $WORKSPACE/manifest.csv
  done<$WORKSPACE/tempKeyFile
  rm $WORKSPACE/tempKeyFile
  if [[ ! -z $3 ]]; then
    gen3_aws_run aws s3 cp $WORKSPACE/manifest.csv s3://"$destination" --profile $3
  else
    gen3_aws_run aws s3 cp $WORKSPACE/manifest.csv s3://"$destination"
  fi
  rm $WORKSPACE/manifest.csv
}

gen3_bucket_manifest_help() {
  gen3 help replicate
}

command="$1"
shift
case "$command" in
  'bucket')
    gen3_replication "$@"
    ;;
  'status')
    gen3_replicate_status "$@"
    ;;
  'help')
    gen3_replicate_help "$@"
    ;;
  *)
    gen3_replicate_help
    ;;
esac
exit $?