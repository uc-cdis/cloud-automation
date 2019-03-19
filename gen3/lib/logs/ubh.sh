# support for: gen3 logs history ubh, gen3 logs save ubh
# ubh == users by hour
#

GEN3_UBH="gen3-ubh"

#
# Process arguments of form 'key=value' to an Elastic Search query
# Supported keys:
#   vpc, start, end, hostname
#
gen3_logs_ubh_raw() {
  local vpcName
  local startDate
  local endDate
  local queryFile

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
# @param startArg defaults to yesterday
#
gen3_logs_ubh_save() {
  local startArg

  startArg="-12 hours"
  if [[ $# -gt 0 ]]; then
    startArg="$1"
    shift
  fi
  
  # first - setup the index if it's not already there
  if ! gen3_logs_ubh_setup; then
    return 1
  fi
  
  # collect stats for each commons not already saved ...
  local vpcName
  local docId
  local hostname
  local userName
  local hourName
  local rawDataFile
  local newDocFile
  local numVpc
  local itVpc
  local numHour
  local itHour
  local numUser
  local itUser
  local numDoc
  local totalDocs

  rawDataFile="$(mktemp "$XDG_RUNTIME_DIR/aggs.json_XXXXXX")"
  newDocFile="$(mktemp "$XDG_RUNTIME_DIR/doc.ndjson_XXXXXX")"
  totalDocs=0
  # ES is a bit flaky - retry a couple times
  gen3_log_info "gen3_logs_ubh_save" "loading unique users from $startArg to + 12 hours"
  if ! gen3_retry gen3_logs_ubh_raw vpc=all "start=$startArg" "end=$startArg + 12 hours" > "$rawDataFile"; then
    gen3_log_err "gen3_logs_ubh_save" "failed to retrieve aggregations"
    rm "$rawDataFile"
    return 1
  fi

  gen3_log_info "gen3_logs_ubh_save" "scanning user data"
  cat "$rawDataFile" 1>&2
  numVpc="$(jq -e -r '.aggregations.by_vpc.buckets | length' < "$rawDataFile")"; 
  if ! gen3_is_number "$numVpc"; then
    gen3_log_err "gen3_logs_ubh_save" "failed to parse numVpc"
    return 1
  fi
  for ((itVpc=0; itVpc<numVpc; itVpc++)); do
    vpcName="$(jq -e -r ".aggregations.by_vpc.buckets[$itVpc].key" < "$rawDataFile")"
    numHour="$(jq -e -r ".aggregations.by_vpc.buckets[$itVpc].by_hour.buckets | length" < "$rawDataFile")"
    if ! gen3_is_number "$numHour"; then
      gen3_log_err "gen3_logs_ubh_save" "failed to parse numHour"
      return 1
    fi
    # fetch the data for this vpc
    hostname="$(gen3_logs_vpc_list | grep -e "^${vpcName} " | awk '{ print $2 }')"
    if [[ -z "$hostname" ]]; then
      gen3_log_err "gen3_logs_ubh_save" "no hostname mapping for $vpcName"
      hostname="$vpcName"
    fi
    
    for ((itHour=0; itHour<numHour; itHour++)); do
      # hour key is ms since epoch, change to secs
      hourName="$(jq -e -r ".aggregations.by_vpc.buckets[$itVpc].by_hour.buckets[$itHour].key" < "$rawDataFile" | sed -E 's/[0-9]{3,3}$//')"
      numUser="$(jq -e -r ".aggregations.by_vpc.buckets[$itVpc].by_hour.buckets[$itHour].by_user.buckets | length" < "$rawDataFile")"
      if ! gen3_is_number "$numUser"; then
        gen3_log_err "gen3_logs_ubh_save" "failed to parse numUser"
        return 1
      fi
      for ((itUser=0; itUser<numUser; itUser++)); do
        userName="$(jq -e -r ".aggregations.by_vpc.buckets[$itVpc].by_hour.buckets[$itHour].by_user.buckets[$itUser].key" < "$rawDataFile")"
        numDoc="$(jq -e -r ".aggregations.by_vpc.buckets[$itVpc].by_hour.buckets[$itHour].by_user.buckets[$itUser].doc_count" < "$rawDataFile")"
        if ! gen3_is_number "$numDoc"; then
          gen3_log_err "gen3_logs_ubh_save" "failed to parse numDoc"
          return 1
        fi
        docId="$(echo "${vpcName}-${hourName}-${userName}" | sed -e 's/[^a-zA-Z0-9-]/_/g')"
        totalDocs="$((totalDocs + numDoc))"
        # prep submission for /_bulk API: https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html
        cat - >> "$newDocFile" <<EOM
{ "index": { "_id": "$docId" } }
{ "vpc_id": "$vpcName", "hostname": "$hostname", "hour_date": "$(gen3_logs_fix_date "@$hourName")", "user_id": "$userName", "hits": $numDoc }
EOM
      done
    done
  done

  local resultFile
  local resultCode
  resultFile="$(mktemp "$XDG_RUNTIME_DIR/result.json_XXXXXX")"
  resultCode=0

  if [[ "$totalDocs" -gt 0 ]]; then
    gen3_log_info "gen3_logs_ubh_save" "saving $totalDocs to /_bulk"
    cat "$newDocFile" 1>&2
    # /_bulk update the documents
    if gen3_retry gen3_logs_curl200 "$GEN3_UBH/infodoc/_bulk" -i -X POST "--data-binary" "@$newDocFile" > "$resultFile"; then
      jq -r . < "$resultFile" 1>&2
    else
      gen3_log_err "gen3_logs_ubh_save" "failed to post /_bulk update"
      cat "$resultFile" 1>&2
      resultCode=1
    fi
  else
    gen3_log_info "gen3_logs_ubh_save" "no new user data found in vpc $vpcName"
  fi
  
  rm "$resultFile"
  rm "$rawDataFile"
  if [[ -f "$newDocFile" ]]; then
    rm "$newDocFile"
  fi
  return $resultCode
}


#
# Fetch window of entries from gen3-ubh.
#
gen3_logs_ubh_history() {
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
    {"hour_date": "asc"},
    {"vpc_id": "asc"},
    {"user_id": "asc"}
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
            "hour_date": {
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
  gen3_retry gen3_logs_curljson "$GEN3_UBH/infodoc/_search?pretty=true" "-d@$queryFile"
  result=$?
  rm "$queryFile"
  return $result
}

