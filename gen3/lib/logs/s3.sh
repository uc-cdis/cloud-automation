#
# Some preliminary code for generating reports from
# the S3 access logs.
# Still under development
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


#
# Generate access reports from S3 logs collected
# over some date range
#
# @param start
# @param end
# @param prefix... s3 logs prefixes
#
gen3_logs_s3() {
  local s3Path
  local startDate
  local endDate
  local prefix
  local inputName
  local outputName
  local lsFiles=()

  startDate="$(date -d "$(gen3_logs_get_arg start 'yesterday' "$@")" "+%Y-%m-%d")"
  endDate="$(date -d "$(gen3_logs_get_arg end 'tomorrow' "$@")" "+%Y-%m-%d")"
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

  gen3_log_info "scanning $prefix"
  aws s3 ls "${prefix}${startDate}" | awk 'BEGIN { done="false"; }; (done == "false" && $4 ~ /'$endDate'/){ done="true"; }; (done == "false") { print $4 };' | tee "${lsTemp}" 1>&2
  # download matching files
  local logPath
  local logFolder
  logFolder="$(dirname "${prefix}")"
  cat "${lsTemp}" | while read -r logPath; do
    gen3_log_info "collecting $logFolder/$logPath"
    if aws s3 cp "${logFolder}/${logPath}" "$downloadTemp" 1>&2; then
      cat "$downloadTemp" >> "$resultTemp"
    fi
  done
  cat "$resultTemp"
  /bin/rm "$resultTemp" "$downloadTemp" "$lsTemp"
  return 0
}


# s3://qaplanetv1-data-bucket-logs/log/qaplanetv1-data-bucket2020
# s3://bhc-bucket-logs s3://bhcprodv2-data-bucket-logs/log/ s3://s3logs-s3logs-mjff-databucket-gen3/log/
# s3://jenkinsv1-data-bucket-logs/log/jenkinsv1-data-bucket2020
# $ cat $XDG_RUNTIME_DIR/s3Result_aRSoKE | grep 'username' | grep GET | awk '{ print $9 }' | sort | uniq -c
