#
# Some helpers for interacting with cloudwatch logs
#
gen3_logs_cwstreams() {
  local logGroup=""

  logGroup="$(gen3_logs_get_arg group "$logGroup" "$@")"
  if [[ -z "$logGroup" ]] && ! logGroup="$(g3kubectl get configmap global -o json | jq -r -e .data.environment)"; then
    # assume it's the environment name
    gen3_log_err "Failed to retrieve environment from global configmap"
    return 1
  fi

  local grepFor="$(gen3_logs_get_arg grep '' "$@")"
  local startDate
  if ! startDate="$((1000*$(date -d "$(gen3_logs_get_arg start 'yesterday' "$@")" "+%s")))"; then
    gen3_log_err "Invalid start date"
    return 1
  fi

  local nextToken
  local temp="$(mktemp "$XDG_RUNTIME_DIR/logGroups.json_XXXXXX")"
  local lastTime="$((1000*$(date +%s)))"
  local count=0
  while [[ "$lastTime" -gt "$startDate" && "$count" -lt 10 ]]; do
    count=$((count+1))
    gen3_log_info "loading page $count from cloudwatch"
    (
      if [[ -n "$nextToken" ]]; then
        aws logs describe-log-streams --log-group-name "$logGroup" --order-by LastEventTime --descending  --page-size 50 --max-items 1000 --starting-token "$nextToken" > "$temp"
      elif [[ $count -gt 1 ]]; then
        gen3_log_err "Err - paging token not set"
        exit 1
      else
        # first batch
        aws logs describe-log-streams --log-group-name "$logGroup" --order-by LastEventTime --descending  --page-size 50 --max-items 1000 > "$temp"
      fi
    )
    if [[ $? -ne 0 ]] ; then
      gen3_log_err "Failed to retrieve log streams under group $logGroup"
      rm "$temp"
      return 1
    fi
    if ! nextToken="$(jq -e -r .NextToken < "$temp")"; then
      gen3_log_err "Failed to retrieve paging token from $temp"
      return 1
    fi
    if ! lastTime="$(jq -e -r '.logStreams | map(.lastEventTimestamp) | min' < "$temp")"; then
      gen3_log_err "Failed to retrieve min creation time from $temp"
      return 1
    fi
    (
      if [[ -n "$grepFor" ]]; then
        jq --arg grepFor "$grepFor" -r '.logStreams[] | .ctime=(.creationTime/1000 | todate) | .ltime=(.lastEventTimestamp/1000 | todate) | select(.logStreamName | contains($grepFor))' < "$temp"
      else
        jq -r '.logStreams[] | .ctime=(.creationTime/1000 | todate) | .ltime=(.lastEventTimestamp/1000 | todate)' < "$temp"
      fi
    )
    if [[ $? -ne 0 ]]; then
      gen3_log_err "Failed to parse log stream $temp"
      return 1
    fi
    gen3_log_info "lastTime is $(date -u -d@$((lastTime/1000)))"
    gen3_log_info "nextToken is $nextToken"
    if [[ $count -gt 9 ]]; then
      gen3_log_info "batch count limit reached: $count"
    fi
    sleep 2  # rate limit
  done
  rm "$temp"
  return 0
}


#
# Retrieve log events
#
gen3_logs_cwevents() {
  local logGroup=""

  logGroup="$(gen3_logs_get_arg group "$logGroup" "$@")"
  if [[ -z "$logGroup" ]] && ! logGroup="$(g3kubectl get configmap global -o json | jq -r -e .data.environment)"; then
    # assume it's the environment name
    gen3_log_err "Failed to retrieve environment from global configmap"
    return 1
  fi

  local name
  for name in "$@"; do
    if [[ -n "$name" && ! "$name" =~ ^group= ]]; then
      if [[ ! -e "$name" ]]; then
        gen3_log_info "retrieving and augmenting log stream: $name"
        aws logs get-log-events --log-group-name "${logGroup}" --log-stream-name "$name" | jq -r '.events[] | .msg=(.message | fromjson | .log) | .ts=(.timestamp/1000 | todate)' | tee "$name"
      else
        gen3_log_info "using local copy of stream: $name"
        cat "$name"
      fi
    fi
  done
}

#
# Subcommand dispatch
#
gen3_logs_cw() {
  local command=""

  if [[ $# -gt 0 ]]; then
    command="$1"
    shift
  fi
  case "$command" in
    "streams")
      gen3_logs_cwstreams "$@"
      ;;
    "events")
      gen3_logs_cwevents "$@"
      ;;
    *)
      gen3_log_err "Use: gen3 logs cloudwatch [streams|events] ..."
      return 1
      ;;
  esac
}
