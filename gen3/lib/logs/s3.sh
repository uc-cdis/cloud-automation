#
# Some preliminary code for generating reports from
# the S3 access logs.
# Still under development
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


#
# urldecode the given argument
#
gen3_logs_urldecode() {
  echo -e ${1//\%/\\x}
}


#
# Run the stdin logstream through a filter to generate a report
#
# @param filter raw, accessCount, whoWhatWhen - see gen3_logs_s3_filer
# @param prefix name of the bucket prefix the stream came from
#
gen3_logs_s3filter() {
  local filterName
  local prefix

  filterName="$(gen3_logs_get_arg filter 'raw' "$@")"
  prefix="$(gen3_logs_get_arg prefix 'unknown/' "$@")"
  local logFolder="$(dirname "${prefix}")"
  
  if [[ "$prefix" =~ /$ ]]; then # no prefix really - just s3://bucket/
    logFolder="${prefix%%/}"
  fi
  case "$filterName" in
    "whoWhatWhen")
      if [[ "$logFolder" != "unknown" ]]; then
        echo -e "Date_time\tPath\tUser_id\tBucket_name"
        grep 'username' | grep GET | awk -v bucket="$logFolder" '{ gsub(/\[/, "", $3); gsub(/.+username=/, "", $11); gsub(/&.*/, "", $11); gsub(/%40/, "@", $11); print $3 "\t" $9 "\t" $11 "\t" bucket }' | sort | sed -E 's/\%[0-9]+/_/g'
      else
        echo -e "Date_time\tPath\tUser_id"
        grep 'username' | grep GET | awk -v bucket="$logFolder" '{ gsub(/\[/, "", $3); gsub(/.+username=/, "", $11); gsub(/&.*/, "", $11); gsub(/%40/, "@", $11); print $3 "\t" $9 "\t" $11 }' | sort | sed -E 's/\%[0-9]+/_/g'
      fi
      ;;
    "accessCount")
      echo -e "Access_count\tPath"
      grep 'username' | grep GET | awk '{ print $9 }' | sort | uniq -c | awk '{ print $1 "\t" $2 }'
      ;;
    *)
      cat -
      ;;
  esac
}


#
# Generate access reports from S3 logs collected
# over some date range
#
# @param start
# @param end up to, but not including end date
# @param prefix... s3 logs prefixes
# @param filter raw, accessCount, whoWhatWhen - see gen3_logs_s3filter
#
gen3_logs_s3() {
  local s3Path
  local startDate
  local endDate
  local prefix
  local inputName
  local outputName
  local lsFiles=()

  if ! startDate="$(date -d "$(gen3_logs_get_arg start 'yesterday' "$@")" "+%Y-%m-%d")"; then
    gen3_log_err "Invalid start date"
    return 1
  fi
  if ! endDate="$(date -d "$(gen3_logs_get_arg end 'tomorrow' "$@")" "+%Y-%m-%d")"; then
    gen3_log_err "Invalid end date"
    return 1
  fi
  prefix="$(gen3_logs_get_arg prefix '' "$@")"
  if [[ -z "$prefix" ]]; then
    gen3_log_err "must specify logs bucket prefix"
    return 1
  fi
  if [[ ! $prefix =~ ^s3:// ]]; then
    gen3_log_err "only support s3 logs bucket currently: $prefix"
    return 1
  fi

  local lsTemp="$(mktemp "$XDG_RUNTIME_DIR/s3Ls_XXXXXX")"
  local downloadTemp="$(mktemp "$XDG_RUNTIME_DIR/s3Download_XXXXXX")"
  local resultTemp="$(mktemp "$XDG_RUNTIME_DIR/s3Result_XXXXXX")"
  local logFolder="$(dirname "${prefix}")"
  
  if [[ "$prefix" =~ /$ ]]; then # no prefix really - just s3://bucket/
    logFolder="${prefix%%/}"
  fi
  local it="${startDate}"
  # iterate day by day
  while [[ "$it" != "${endDate}" ]]; do
    gen3_log_info "scanning ${prefix}${it}"
    aws s3 ls "${prefix}${it}" | awk '{ print $4 }' | tee "${lsTemp}" 1>&2
    local logPath
    cat "${lsTemp}" | while read -r logPath; do
      gen3_log_info "collecting $logFolder/$logPath"
      if aws s3 cp "${logFolder}/${logPath}" "$downloadTemp" 1>&2; then
        cat "$downloadTemp" >> "$resultTemp"
      fi
    done

    local timestamp
    timestamp="$(date -u -d "$it" "+%s")"
    timestamp="$((timestamp + 60*60*24))"
    it="$(date "-d@$timestamp" "+%Y-%m-%d")"
  done
  cat "$resultTemp" | gen3_logs_s3filter "$@"
  /bin/rm "$resultTemp" "$downloadTemp" "$lsTemp"
  return 0
}


# s3://qaplanetv1-data-bucket-logs/log/qaplanetv1-data-bucket2020
# s3://jenkinsv1-data-bucket-logs/log/jenkinsv1-data-bucket2020
#
# s3://s3logs-s3logs-mjff-databucket-gen3/log/mjff-databucket-gen3
# s3://bhc-bucket-logs 
# s3://bhcprodv2-data-bucket-logs/log/bhcprodv2-data-bucket2020 
#
# $ cat $XDG_RUNTIME_DIR/s3Result_aRSoKE | grep 'username' | grep GET | awk '{ print $9 }' | sort | uniq -c
