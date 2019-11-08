gen3_load "gen3/lib/logs/job"

#
# Process arguments of form 'key=value' to an Elastic Search query
# Supported keys:
#   vpc, start, end, user, visitor, session, service, proxy, aggs (yes, no), fields (log, all, none), page
#
gen3_logs_rawlog_query() {
  local vpcName
  local pageNum
  local fromNum
  local startDate
  local endDate
  local serviceName
  local proxyService
  local queryFile
  local userId
  local sessionId
  local visitorId
  local statusMin
  local statusMax
  local aggs   # aggregations
  local fields 

  vpcName="$(gen3_logs_get_arg vpc "${vpc_name:-"all"}" "$@")"
  userId="$(gen3_logs_get_arg user "" "$@")"
  visitorId="$(gen3_logs_get_arg visitor "" "$@")"
  sessionId="$(gen3_logs_get_arg session "" "$@")"
  startDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg start 'yesterday 00:00' "$@")")"
  endDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg end 'tomorrow 00:00' "$@")")"
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  serviceName="$(gen3_logs_get_arg service revproxy "$@")"
  proxyService="$(gen3_logs_get_arg proxy "all" "$@")"
  statusMin="$(gen3_logs_get_arg statusmin 0 "$@")"
  statusMax="$(gen3_logs_get_arg statusmax 1000 "$@")"
  aggs="$(gen3_logs_get_arg aggs no "$@")"
  fields="log"
  if [[ "$aggs" == "yes" ]]; then # no search fields by default when aggregations on
    fields="none"
  fi
  fields="$(gen3_logs_get_arg fields "$fields" "$@")"

  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsQuery.json_XXXXXX")
  fromNum=$((pageNum * 1000))
  
  cat - > "$queryFile" <<EOM
{
  "from": ${fromNum},
  
  $(
    if [[ "$fields" != "none" ]]; then
      cat - <<ENESTED
  "size": 1000,
  "sort": [
    {"timestamp": "asc"}
    ],
ENESTED
      if [[ "$fields" != "all" ]]; then   
        cat - <<ENESTED
  "_source": [ "message.log" ],
ENESTED
      fi
    else
      cat - <<ENESTED
  "_source": [],
  "size": 0,
ENESTED
    fi
  )
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
        $(
          if [[ -n "$userId" ]]; then
            cat - <<ENESTED
            {"term": {"message.user_id.keyword": "$userId"}},
ENESTED
          else echo ""
          fi
        )
        $(
          if [[ -n "$visitorId" ]]; then
            cat - <<ENESTED
            {"term": {"message.visitor_id.keyword": "$visitorId"}},
ENESTED
          else echo ""
          fi
        )
        $(
          if [[ -n "$sessionId" ]]; then
            cat - <<ENESTED
            {"term": {"message.session_id.keyword": "$sessionId"}},
ENESTED
          else echo ""
          fi
        )
        $(
          if [[ "$serviceName" == "revproxy" && -n "$proxyService" && "$proxyService" != "all" ]]; then
            cat - <<ENESTED
            {"term": {"message.proxy_service.keyword": "$proxyService"}},
ENESTED
          else echo ""
          fi
        )
        $(
          if [[ "$statusMin" -gt 0 || "$statusMax" -lt 1000 ]]; then
            cat - <<ENESTED
        { 
          "range": {
            "message.http_status_code": {
              "gte": $statusMin,
              "lte": $statusMax
            }
          }
        },
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
$(
  if [[ "$aggs" == "yes" ]]; then
    # see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-metrics-cardinality-aggregation.html
    cat - <<ENESTED
  , "aggregations": {
    "vpc": {
      "terms" : { "field": "_type"},
      "aggregations": {
        "unique_user_count" : {
            "cardinality" : {
                "field" : "message.user_id.keyword",
                "precision_threshold": 1000
            }
        }
      }
    }
  }
ENESTED
  fi
)
}
EOM
  cat "$queryFile"  # show the user the query, so can tweak by hand
  rm $queryFile
  return 0
}


#
# Helper to search the logs for a particular/all services
# in a particular date range for a particular/all vpc.
# Accepts some extra key=value arguments - first option is the default:
#
# @parma format=raw|json
# @param page=0|number|all
# @param qtype=raw|job whether to raw query services or jobs
# @return to stdout the results in the requested format, also write
#     to stderr the /_search query sent to elastic search
#
gen3_logs_rawlog_search() {
  local queryStr
  local queryFile
  local format
  local jsonFile
  local pageNum
  local pageIt
  local pageMin
  local pageMax
  local pageSize
  local totalRecs
  local errStr
  local aggs
  local fields
  local qtype

  pageSize=1000
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  aggs="$(gen3_logs_get_arg aggs no "$@")"
  qtype="$(gen3_logs_get_arg qtype raw "$@")"

  fields="log"
  if [[ "$aggs" == "yes" ]]; then # no search fields by default when aggregations on
    fields="none"
  fi
  fields="$(gen3_logs_get_arg fields "$fields" "$@")"
  format="raw"
  if [[ "$aggs" == "yes" || "$fields" == "all" ]]; then
    format="json"
  fi
  format="$(gen3_logs_get_arg format "$format" "$@")"
  
  # Support retrieving all pages
  if [[ $pageNum =~ ^[0-9][0-9]*$ ]]; then
    pageIt=$pageNum
    pageMax=$((pageNum + 1))
  elif [[ $pageNum =~ ^[0-9][0-9]*-[0-9][0-9]*$ ]]; then
    pageMax=$(echo $pageNum | sed -e 's/^.*-//')
    let pageMax+=1  # we do a 'less than' comparison below
    pageIt=$(echo $pageNum | sed -e 's/-.*$//')
  elif [[ $pageNum == "all" ]]; then
    pageMax="all"
    pageIt=0
  else
    gen3_log_err "gen3_logs_rawlog_search" "invalid page $pageNum - setting to 0"
    pageIt=0
    pageMax=1
  fi
  pageMin=$pageIt
  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsSearch.json_XXXXXX")
  jsonFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsResult.json_XXXXXX")
  # our ES cluster is setup with a 10000 record max result size
  while [[ $pageIt -lt 10 && ($pageMax == "all" || $pageIt -lt $pageMax) ]]; do
    # first key=value takes precedence in argument processing, so just put page first
    if [[ "$qtype" != "job" ]]; then
      queryStr="$(gen3_logs_rawlog_query "page=$pageIt" "$@")"
    else
      queryStr="$(gen3_logs_joblog_query "page=$pageIt" "$@")"
    fi
    tee "$queryFile" 1>&2 <<EOM
$queryStr
EOM
    echo "--------------------------" 1>&2
    if ! gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d@$queryFile" > $jsonFile; then
      rm "$queryFile" "$jsonFile"
      return 1
    fi
    rm "$queryFile"
    # check integrity of result
    errStr="$(jq -r .error < "$jsonFile")"
    if [[ "$errStr" != null ]]; then
      gen3_log_err "gen3_logs_rawlog_search" "error from server"
      cat - 1>&2 <<EOM
$errStr
EOM
      cat "$jsonFile" 1>&2
      rm "$jsonFile"
      return 1
    fi
    if ! jq -r .hits.total > /dev/null 2>&1 < $jsonFile; then
      gen3_log_err "gen3_logs_rawlog_search" "unable to parse search result"
      cat "$jsonFile" 1>&2
      rm "$jsonFile"
      return 1
    fi

    if [[ "$format" == "json" ]]; then
      cat "$jsonFile"
    elif [[ "$qtype" == "job" ]]; then
      cat "$jsonFile" | jq -r '.hits.hits[] | [._index, "-", ._source.timestamp, ":", ._source.message.log] | join(" ")' | grep -e '.' --color="never"
    else
      cat "$jsonFile" | jq -r '.hits.hits[] | ._source.message.log' | grep -e '.' --color="never"
    fi
    if [[ -z "$totalRecs" ]]; then
      totalRecs=$(jq -r .hits.total < "$jsonFile")
    fi
    if [[ $pageMax == "all" ]]; then
      # compute pageMax from the total records in the first page result
      pageMax=$(( totalRecs / pageSize)) # note - this rounds down
      if [[ $((pageMax * pageSize)) -lt $((totalRecs)) ]]; then # deal with rounding errors
        let pageMax+=2
      else
        let pageMax+=1
      fi
    fi
    rm "$jsonFile"
    gen3_log_info "gen3_logs_rawlog_search" "total_records=$totalRecs, pageSize=1000, pageMin=$pageMin, pageMax=$pageMax, lastPage=$pageIt"
    let pageIt+=1
  done

  if [[ $pageIt -lt $pageMax && $pageMax -gt 10 ]]; then
    gen3_log_err "gen3_logs_rawlog_search" "Only retrieved $pageIt of $pageMax pages - 10000 record max result size"
  fi
}

