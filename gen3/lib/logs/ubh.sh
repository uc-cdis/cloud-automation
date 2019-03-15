# support for: gen3 logs history ubh, gen3 logs save ubh
# ubh == users by hour
#

GEN3_UBH="gen3-ubh"

#
# Process arguments of form 'key=value' to an Elastic Search query
# Supported keys:
#   vpc, start, end, user, visitor, session, service, aggs (yes, no), fields (log, all, none), page
#
gen3_logs_ubh_raw() {
  local vpcName
  local startDate
  local endDate
  local queryFile
  local userId
  local sessionId
  local visitorId
  local statusMin
  local statusMax
  local aggs   # aggregations
  local fields 

  vpcName="$(gen3_logs_get_arg vpc "${vpc_name:-"all"}" "$@")"
  startDate="$(date --utc --date "$(gen3_logs_get_arg start '-12 hour' "$@")"  '+%Y/%m/%d %H:00')"
  endDate="$(date --utc --date "$(gen3_logs_get_arg end 'now' "$@")" '+%Y/%m/%d %H:00')"
  
  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsQuery.json_XXXXXX")

  # see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-metrics-cardinality-aggregation.html  
  cat - > "$queryFile" <<EOM
{
  "_source": [],
  "size": 0,
  "query": {
    "bool": {
      "must": [
        {"term": {
          "message.kubernetes.container_name.keyword": "revproxy"
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
  },
  "aggs": {
    "by_vpc": {
      "terms": { "field": "_type"},
      "aggs": {
        "by_hour": {
          "date_histogram": {
            "field": "timestamp",
            "interval": "hour"
          },
          "aggs": {
              "by_user" : {
                "terms": { "field": "message.user_id.keyword" }
              }
          }
        }
      }
    }
  }
}
EOM
  local result
  
  if jq -e -r . < "$queryFile" 1>&2; then
    gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d@$queryFile"
    result=$?
  else
    result=1
    gen3_log_err "gen3_logs_ubh" "query failed json validation"
    cat "$queryFile" 1>&2
  fi
  rm "$queryFile"
  return $result
}


#
# Create the users-by-hour index if it
# does not already exist
#
gen3_logs_ubh_setup() {
  if ! gen3_logs_curl200 "$GEN3_UBH" > /dev/null 2>&1; then
    # setup aggregations index
    if ! gen3_logs_curl200 "$GEN3_UBH" -X PUT -d'
{
    "mappings": {
      "infodoc": {
        "properties": {
          "vpc_id": { "type": "keyword" },
          "hostname": { "type": "keyword" },
          "hour_date": { "type": "date", "format": "yyyy/MM/dd HH:mm" },
          "user_id": { "type": "keyword" },
          "hits": { "type": "integer" }
        }
      }
    }
}
'; then
      gen3_log_err "gen3_logs_ubh_setup" "failed to setup index mapping"
      return 1
    fi
  fi
  return 0
}


#
# Save per-commons aggregations for yesterday
#
# @param dayArg defaults to yesterday
#
gen3_logs_ubh_save() {
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
  if ! gen3_logs_ubh_setup; then
    return 1
  fi
  
  # collect stats for each commons not already saved ...
  local vpcName
  local docId
  local hostname
  local userId
  local hitCount
  local hourDate
  local rawDataFile
  local newDocFile
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
      if ! gen3_retry gen3_logs_curl200 "$GEN3_UBH/infodoc/${docId}?pretty=true" -i -X PUT "-d@$docFile" 1>&2; then
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

