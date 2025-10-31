
#
# Process arguments of form 'key=value' to an Elastic Search query
# Supported keys:
#   vpc, start, end, user, visitor, session, jname, fields (log, all, none), page
#
gen3_logs_joblog_query() {
  local vpcName
  local pageNum
  local fromNum
  local startDate
  local endDate
  local jobName
  local queryFile
  local userId
  local sessionId
  local visitorId
  local statusMin
  local statusMax
  local aggs   # aggregations
  local fields
  local app="gen3job"

  app="$(gen3_logs_get_arg app "${app}" "$@")"
  vpcName="$(gen3_logs_get_arg vpc "${vpc_name:-"all"}" "$@")"
  startDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg start 'yesterday 00:00' "$@")")"
  endDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg end 'tomorrow 00:00' "$@")")"
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  jobName="$(gen3_logs_get_arg jname "usersync" "$@")"
  fields="$(gen3_logs_get_arg fields "log" "$@")"

  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsQuery.json_XXXXXX")
  fromNum=$((pageNum * 1000))
  
  cat - > "$queryFile" <<EOM
{
  "from": ${fromNum},
  
  $(
      cat - <<ENESTED
  "size": 1000,
  "sort": [
    {"timestamp": "asc"}
    ],
ENESTED
      if [[ "$fields" != "all" ]]; then   
        cat - <<ENESTED
  "_source": [ "message.log", "timestamp" ],
ENESTED
      fi
  )
  "query": {
    "bool": {
      "must": [
        {"prefix": {
          "message.kubernetes.labels.job-name.keyword": "${jobName}"
        }},
        {"term": {
          "message.kubernetes.labels.app": "$app"
        }},
        $(
          if [[ "$vpcName" != all ]]; then
            cat - <<ENESTED
            {"term": {"logGroup": "$vpcName"}},
ENESTED
          else echo ""
          fi
        )
        { 
          "range": {
            "timestamp": {
              "gte": "$startDate",
              "lte": "$endDate",
              "format": "yyyy/MM/dd HH:mm"
            }
          }
        }
      ]
    }
  }
}
EOM
  cat "$queryFile"  # show the user the query, so can tweak by hand
  rm $queryFile
  return 0
}

