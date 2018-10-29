#!/bin/bash
#
# Helper to query elastic search logs database
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

LOGHOST=kibana.planx-pla.net
LOGUSER=kibanaadmin
LOGPASSWORD="${LOGPASSWORD:-""}"


#
# Little helper - first argument is key,
# remaining arguments are of form "key=value" to search through for that key
# @param key
# @param defaultValue echo $default if not key not found
# @return echo the value extracted from remaining arguments or "" if not found
#
gen3_logs_get_arg() {
  if [[ $# -lt 2 || -z "$1" || "$1" =~ /=/ ]]; then
    echo -e "$(red_color "ERROR: no valid key to gen3_logs_get_arg")" 1>&2
    echo ""
    return 1
  fi
  local key
  local entry
  local defaultValue
  key="$1"
  shift
  defaultValue="$1"
  shift
  for entry in "$@"; do
    if [[ "$entry" =~ ^${key}= ]]; then
      echo "$entry" | sed "s/^${key}=//"
      return 0
    fi
  done
  echo "$defaultValue"
  return 1
}

gen3_logs_fix_date() {
  local dt
  dt="$1"
  date --utc --date "$dt" '+%Y/%m/%d %H:%M'
}

#
# Process arguments of form 'key=value' to an Elastic Search query
# Supported keys:
#   vpc, start, end, service, page
#
gen3_logs_rawlog_query() {
  local vpcName
  local pageNum
  local fromNum
  local startDate
  local endDate
  local serviceName
  local queryFile

  vpcName="$(gen3_logs_get_arg vpc "${vpc_name:-"all"}" "$@")"
  startDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg start "$(gen3_logs_fix_date 'yesterday 00:00')" "$@")")"
  endDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg end "$(gen3_logs_fix_date 'tomorrow 00:00')" "$@")")"
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  serviceName="$(gen3_logs_get_arg service revproxy "$@")"

  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsQuery.json_XXXXXX")
  fromNum=$(($pageNum * 1000))
  cat - > "$queryFile" <<EOM
{
  "from": ${fromNum},
  "size": 1000,
  "_source": [ "message.log" ],
  "sort": [
    {"timestamp": "asc"}
  ],
  "query": {
    "bool": {
      "must": [
        {"term": {
          "message.kubernetes.container_name.keyword": "$serviceName"
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
            "timestamp" : {
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
  unlink $queryFile
  return 0
}

gen3_logs_rawlog_search() {
  local queryStr
  local queryFile
  local format
  local jsonFile
  format="$(gen3_logs_get_arg format raw "$@")"
  queryStr="$(gen3_logs_rawlog_query "$@")"
  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsSearch.json_XXXXXX")
  jsonFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsResult.json_XXXXXX")

  tee "$queryFile" 1>&2 <<EOM
$queryStr

--------------------------
EOM
  curl -u "${LOGUSER}:${LOGPASSWORD}" -X GET "$LOGHOST/_all/_search?pretty=true" "-d@$queryFile" > $jsonFile
  unlink "$queryFile"
  if [[ "$format" == "json" ]]; then
    cat "$jsonFile"
  else
    echo "INFO: total_records $(jq -r .hits.total < "$jsonFile")" 1>&2
    cat "$jsonFile" | jq -r '.hits.hits[] | ._source.message.log' | grep -e '.' --color="never"
  fi
  unlink "$jsonFile"
}

gen3_logs_help() {
  gen3 help logs
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
    gen3_logs_help
    exit 0
  fi

  shift
  gen3_logs_rawlog_search "$@"
fi
