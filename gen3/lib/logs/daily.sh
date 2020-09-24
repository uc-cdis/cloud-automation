# support for: gen3 logs history daily, gen3 logs save daily

GEN3_AGGS_DAILY="gen3-aggs-daily"


#
# Get the number of unique users
#
gen3_logs_user_count() {
    local queryStr="$(gen3 logs rawq "$@" aggs=yes)"
    local aggs="$(cat - <<EOM
  {
      "unique_user_count" : {
        "cardinality" : {
            "field" : "message.user_id.keyword",
            "precision_threshold": 10
        }
      }
  }
EOM
    )"
    local namespace="$(cat - <<EOM
{"term": {
  "message.kubernetes.namespace_name.keyword": "default"
}}
EOM
    )";
    queryStr=$(jq -r --argjson aggs "$aggs" --argjson ns "$namespace" '.aggregations=$aggs | .query.bool.must += [ $ns ]' <<<${queryStr})
    
    gen3_log_info "$queryStr"
    gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d${queryStr}"  
}

#
# HTTP response code histogram
#
gen3_logs_code_histogram() {
    local queryStr="$(gen3 logs rawq "$@" aggs=yes)"
    local aggs=$(cat - <<EOM
  {
      "codes" : {
          "histogram" : {
              "field" : "message.http_status_code",
              "interval" : 1,
              "min_doc_count" : 1
          }
      }
  }
EOM
    )
    local namespace="$(cat - <<EOM
{"term": {
  "message.kubernetes.namespace_name.keyword": "default"
}}
EOM
    )";
    queryStr=$(jq -r --argjson aggs "$aggs" --argjson ns "$namespace" '.aggregations=$aggs | .query.bool.must += [ $ns ]' <<<${queryStr})
    gen3_log_info "$queryStr"
    gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d${queryStr}"  
}

gen3_logs_user_histogram() {
    local queryStr="$(gen3 logs rawq "$@" aggs=yes)"
    local aggs="$(cat - <<EOM
  {
      "users" : {
          "terms" : {
              "field" : "message.user_id.keyword",
              "size"  : 100
          }
      }
  }
EOM
    )"
    local namespace="$(cat - <<EOM
{"term": {
  "message.kubernetes.namespace_name.keyword": "default"
}}
EOM
    )";
    queryStr=$(jq -r --argjson aggs "$aggs" --argjson ns "$namespace" '.aggregations=$aggs | .query.bool.must += [ $ns ]' <<<${queryStr})
    
    gen3_log_info "$queryStr"
    gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d${queryStr}"  
}

#
# Response time histogram
#
gen3_logs_rtime_histogram() {
    local queryStr="$(gen3 logs rawq "$@" aggs=yes)"
    local aggs=$(cat - <<EOM
  {
      "rtimes" : {
          "histogram" : {
              "field" : "message.response_secs",
              "interval" : 0.1,
              "min_doc_count" : 1
          }
      }
  }
EOM
    )
    local namespace="$(cat - <<EOM
{"term": {
  "message.kubernetes.namespace_name.keyword": "default"
}}
EOM
    )";
    queryStr=$(jq -r --argjson aggs "$aggs" --argjson ns "$namespace" '.aggregations=$aggs | .query.bool.must += [ $ns ]' <<<${queryStr})
    gen3_log_info "$queryStr"
    gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d${queryStr}"  
}

#
# Fetch the unique users aggregations from 'gen3 logs raw aggs=yes'.
# Internal helper for building up the unique users history table.
#
# @param dayArg like 'yesterday' or '03/01/2019' to fetch aggregations for
# @return 0 on success, and cat json search data
#
gen3_logs_fetch_aggs() {
  local aggsFile
  local dayArg

  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_logs_fetch_aggs" "must pass dayArg to query for aggregations"
    return 1
  fi
  dayArg="$1"
  aggsFile="$(mktemp "$XDG_RUNTIME_DIR/aggsfetch.json_XXXXXX")"

  gen3_log_info "gen3_logs_fetch_aggs" "collecting daily aggregations for $dayArg"
  gen3_logs_rawlog_search "aggs=yes" "vpc=all" "start=$dayArg 00:00" "end=$dayArg + 1 day 00:00" > "$aggsFile"
  # this will fail if the data is not json
  if jq -e -r . > /dev/null 2>&1 < "$aggsFile"; then
    cat "$aggsFile"
    rm "$aggsFile"
    return 0
  else
    gen3_log_err "gen3_logs_fetch_aggs" "failed verifying query results ..."
    cat "$aggsFile" 1>&2
    rm "$aggsFile"
    return 1
  fi
}

#
# Response time histogram
#
gen3_logs_uniques() {
    local queryStr="$(gen3 logs rawq "$@" aggs=yes)"
    local aggs=$(cat - <<EOM
  {
      "rtimes" : {
          "histogram" : {
              "field" : "message.response_secs",
              "interval" : 0.1,
              "min_doc_count" : 1
          }
      }
  }
EOM
    )
    queryStr=$(jq -r --argjson aggs "$aggs" '.aggs=$aggs' <<<${queryStr})
    gen3_log_info "$queryStr"
    gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d${queryStr}"  
}


#
# Save per-commons aggregations for yesterday
#
# @param dayArg defaults to yesterday
#
gen3_logs_save_daily() {
  local dayDate
  local dayKey
  local dayArg

  dayArg="yesterday"
  if [[ $# -gt 0 ]]; then
    dayArg="$1"
    shift
  fi
  dayDate="$(gen3_logs_fix_date "$dayArg 00:00")"
  dayKey="$(date --utc --date "$dayArg 00:00" '+%Y%m%d')"

  # first - setup the index if it's not already there
  if ! gen3_logs_curl200 "$GEN3_AGGS_DAILY" > /dev/null 2>&1; then
    # setup aggregations index
    if ! gen3_logs_curl200 "$GEN3_AGGS_DAILY" -X PUT -d'
{
    "mappings": {
      "infodoc": {
        "properties": {
          "vpc_id": { "type": "keyword" },
          "hostname": { "type": "keyword" },
          "day_date": { "type": "date", "format": "yyyy/MM/dd HH:mm" },
          "unique_users": { "type": "integer" }
        }
      }
    }
}
'; then
      gen3_log_err "gen3_logs_save_daily" "failed to setup index mapping"
      return 1
    fi
  fi

  # collect stats for each commons not already saved ...
  local vpcName
  local docId
  local hostname
  local usercount
  local aggsFile
  local docFile
  aggsFile="$(mktemp "$XDG_RUNTIME_DIR/aggs.json_XXXXXX")"
  docFile="$(mktemp "$XDG_RUNTIME_DIR/doc.json_XXXXXX")"

  # ES is a bit flaky - retry a couple times
  if ! gen3_retry gen3_logs_fetch_aggs "$dayArg" > "$aggsFile"; then
    gen3_log_err "gen3_logs_daily_save" "failed to retrieve aggregations"
    rm "$aggsFile"
    return 1
  fi

  for vpcName in $(jq -r '.aggregations.vpc.buckets | map(.key) | join("\n")' < "$aggsFile"); do
    docId="${dayKey}-${vpcName}"
    # fetch the data for this vpc
    hostname="$(gen3_logs_vpc_list | grep -e "^${vpcName} " | awk '{ print $2 }')"
    if [[ -z "$hostname" ]]; then
      gen3_log_err "gen3_logs_save_daily" "no hostname mapping for $vpcName"
      hostname="$vpcName"
    fi
    usercount="$(jq -r ".aggregations.vpc.buckets | map(select(.key==\"$vpcName\")) | .[0] | .unique_user_count.value" < "$aggsFile" )"
    if [[ -n "$usercount" && "$usercount" =~ ^[0-9]+$ ]]; then
      cat - > "$docFile" <<EOM
{
  "vpc_id": "$vpcName",
  "hostname": "$hostname",
  "day_date": "$dayDate",
  "unique_users": $usercount
}
EOM
      gen3_log_info "gen3_logs_save_daily" "saving $docId"
      cat "$docFile" 1>&2
      # update the document
      if ! gen3_retry gen3_logs_curl200 "$GEN3_AGGS_DAILY/infodoc/${docId}?pretty=true" -i -X PUT "-d@$docFile" 1>&2; then
        gen3_log_err "gen3_logs_save_daily" "failed to save user count for vpc $vpcName"
      fi
    else
      gen3_log_err "gen3_logs_save_daily" "failed to extract user count for vpc $vpcName"
    fi
  done
  rm "$aggsFile"
  if [[ -f "$docFile" ]]; then
    rm "$docFile"
  fi
}

#
# Query the daily history table.  Accepts query parameters
# similar to raw query: vpc=bla, start=bla, end=bla, hostname=bla
#
gen3_logs_history_daily() {
  local queryFile
  local vpcName
  local pageNum
  local fromNum
  local startDate
  local endDate
  local hostname

  vpcName="$(gen3_logs_get_arg vpc "${vpc_name:-"all"}" "$@")"
  hostname="$(gen3_logs_get_arg hostname "" "$@")"
  startDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg start 'yesterday 00:00' "$@")")"
  endDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg end 'tomorrow 00:00' "$@")")"
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  fromNum=$((pageNum * 1000))
  if [[ -n "$hostname" ]]; then vpcName=all; fi
  
  queryFile="$(mktemp "$XDG_RUNTIME_DIR/esquery.json_XXXXXX")"
  cat - > "$queryFile" <<EOM
{
  "from": ${fromNum},
  "size": 1000,
  "sort": [
    {"day_date": "asc"},
    {"vpc_id": "asc"}
  ],
  "query": {
    "bool": {
      "must": [
        $(
          if [[ "$vpcName" != all ]]; then
            cat - <<ENESTED
            {"term": {"vpc_id": "$vpcName"}},
ENESTED
          else echo ""
          fi
        )
        $(
          if [[ -n "$hostname" ]]; then
            cat - <<ENESTED
            {"term": {"hostname": "$hostname"}},
ENESTED
          else echo ""
          fi
        )
        { 
          "range": {
            "day_date": {
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

  cat "$queryFile" 1>&2
  local result
  gen3_retry gen3_logs_curljson "$GEN3_AGGS_DAILY/infodoc/_search?pretty=true" "-d@$queryFile"
  result=$?
  rm "$queryFile"
  return $result
}

