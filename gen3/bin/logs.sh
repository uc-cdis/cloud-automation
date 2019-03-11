#!/bin/bash
#
# Helper to query elastic search logs database
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

LOGHOST="${LOGHOST:-https://kibana.planx-pla.net}"
LOGUSER="${LOGUSER:-kibanaadmin}"
LOGPASSWORD="${LOGPASSWORD:-"deprecated"}"

if [[ -z "$vpc_name" ]]; then
  vpc_name="$(g3kubectl get configmap global -o json | jq -r .data.environment)"
fi


gen3LogsVpcList=(
    "edcprodv2 portal.occ-data.org environmental data commons"
    "prodv1 data.kidsfirstdrc.org kids first"
    "skfqa gen3qa.kidsfirstdrc.org kids first"
    "devplanetv1 dev.planx-pla.net"
    "qaplanetv1 qa.planx-pla.net jenkins"
    "bloodv2 data.bloodpac.org"
    "bhcprodv2 data.braincommons.org cvb"
    "gtexprod dcp.bionimbus.org"
    "dcfqav1 qa.dcf.planx-pla.net"
    "niaidprod niaid.bionimbus.org"  
    # -----------------------------------
    "accountprod  acct.bionimbus.org"
    "anvilprod theanvil.io"
    "anvilstaging staging.theavil.io"
    "kfqa dcf-interop.kidsfirstdrc.org"
    "dcfprod nci-crdc.datacommons.io"
    "dcf-staging nci-crdc-staging.datacommons.io"
    "genomelprod genomel.bionimbus.org"
    "stageprod gen3.datastage.io"
    "vadcprod vpodc.org"
    "ibdgc-prod ibdgc.datacommons.io"
    "ncicrdcdemo nci-crdc-demo.datacommons.io"
)

#
# Dump vpclist
# The output lists one vpc per line where
# the first two tokens of each line are the
# `vpcName` and one `hostname` associated with
# a commons running in that vpc:
# ```
# vpcName hostname other descriptive stuff to grep on
# ```
#
gen3_logs_vpc_list() {
  local info
  for info in "${gen3LogsVpcList[@]}"; do
    echo "$info"
  done
}

#
# Little helper - first argument is key,
# remaining arguments are of form "key=value" to search through for that key
# @param key
# @param defaultValue echo $default if not key not found
# @return echo the value extracted from remaining arguments or "" if not found
#
gen3_logs_get_arg() {
  if [[ $# -lt 2 || -z "$1" || "$1" =~ /=/ ]]; then
    gen3_log_err "gen3_logs_get_arg" "no valid key to gen3_logs_get_arg"
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
#   vpc, start, end, user, visitor, session, service, aggs (yes, no), fields (log, all, none), page
#
gen3_logs_rawlog_query() {
  local vpcName
  local pageNum
  local fromNum
  local startDate
  local endDate
  local serviceName
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
  startDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg start "$(gen3_logs_fix_date 'yesterday 00:00')" "$@")")"
  endDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg end "$(gen3_logs_fix_date 'tomorrow 00:00')" "$@")")"
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  serviceName="$(gen3_logs_get_arg service revproxy "$@")"
  statusMin="$(gen3_logs_get_arg statusmin 0 "$@")"
  statusMax="$(gen3_logs_get_arg statusmax 1000 "$@")"
  aggs="$(gen3_logs_get_arg aggs no "$@")"
  fields="log"
  if [[ "$aggs" == "yes" ]]; then # no search fields by default when aggregations on
    fields="none"
  fi
  fields="$(gen3_logs_get_arg fields "$fields" "$@")"

  queryFile=$(mktemp -p "$XDG_RUNTIME_DIR" "esLogsQuery.json_XXXXXX")
  fromNum=$(($pageNum * 1000))
  
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
        { 
          "range": {
            "timestamp": {
              "gte": "$startDate",
              "lte": "$endDate",
              "format": "yyyy/MM/dd HH:mm"
            }
          }
        },
        { 
          "range": {
            "message.http_status_code": {
              "gte": $statusMin,
              "lte": $statusMax
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

  pageSize=1000
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  aggs="$(gen3_logs_get_arg aggs no "$@")"
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
  
  if [[ -z "$LOGPASSWORD" ]]; then
    gen3_log_err "gen3_logs_rawlog_search" "LOGPASSWORD environment not set"
    return 1
  fi
  # Support retrieving all pages
  if [[ $pageNum =~ ^[0-9][0-9]*$ ]]; then
    pageIt=$pageNum
    pageMax=$(($pageNum + 1))
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
    queryStr="$(gen3_logs_rawlog_query "page=$pageIt" "$@")"
    tee "$queryFile" 1>&2 <<EOM
$queryStr

--------------------------
EOM
    if ! gen3_retry gen3_logs_curljson "_all/_search?pretty=true" "-d@$queryFile" > $jsonFile; then
      rm "$queryFile" "$jsonFIle"
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
    else
      cat "$jsonFile" | jq -r '.hits.hits[] | ._source.message.log' | grep -e '.' --color="never"
    fi
    if [[ -z "$totalRecs" ]]; then
      totalRecs=$(jq -r .hits.total < "$jsonFile")
    fi
    if [[ $pageMax == "all" ]]; then
      # compute pageMax from the total records in the first page result
      pageMax=$(( $totalRecs / $pageSize)) # note - this rounds down
      if [[ $(($pageMax * $pageSize)) -lt $((totalRecs)) ]]; then # deal with rounding errors
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

#
# Little wrapper around curl that always passes '-s', '-u user:password', '-H Content-Tpe application/json',
# plus other args passed as inputs
#
# @param path under $LOGHOST/ to curl
# @param ... other curl args
#
gen3_logs_curl() {
  local path
  local fullPath

  if [[ $# -gt 0 ]]; then
    path="$1"
    shift
  else
    path="_cat/indices"
  fi
  if [[ "$path" =~ ^https?:// ]]; then
    fullPath="$path"
  else
    fullPath="$LOGHOST/$path"
  fi
  gen3_log_info "gen3_logs_curl" "$fullPath"
  curl -s -u "${LOGUSER}:${LOGPASSWORD}" -H 'Content-Type: application/json' "$fullPath" "$@"
}


#
# Same as gen3_logs_curl, but passes -i, and fails if  HTTP result is not 200 - sending output to stderr
#
gen3_logs_curl200() {
  local tempFile
  local result
  local path
  local httpStatus
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/curl.json_XXXXXX")"
  result=0
  path="$1"
  if ! gen3_logs_curl "$@" -i > "$tempFile"; then
    gen3_log_err "gen3_logs_curl200" "non-zero exit from curl $path"
    cat "$tempFile" 1>&2
    result=1
  elif (head -1 "$tempFile" | grep -e '^HTTP' > /dev/null 2>&1) && httpStatus="$(head -1 "$tempFile" | awk '{ print $2 }')" && [[ "$httpStatus" == 200  || "$httpStatus" == 201 ]]; then
    # looks like HTTP/.. 200!
    awk '(body == "true") { print $0 }; /^[\r\n\s]*$/ { body="true" }' < "$tempFile"
    result=0
  else
    gen3_log_err "gen3_logs_curl200" "non-200 from curl $path"
    cat "$tempFile" 1>&2
    result=1
  fi
  rm "$tempFile"
  return $result      
}

#
# Same as gen3_logs_curl200, but passes the output through 'jq -e -r .'
# to verify, and returns that exit code.  On failure sends output to stderr instead of stdout
#
gen3_logs_curljson() {
  local tempFile
  local result
  local path
  tempFile="$(mktemp "$XDG_RUNTIME_DIR/curl.json_XXXXXX")"
  result=0
  path="$1"
  if ! gen3_logs_curl200 "$@" > "$tempFile"; then
    result=1
  elif jq -e -r . < "$tempFile" > /dev/null 2>&1; then
    cat "$tempFile"
    result=0
  else
    result=1
    gen3_log_err "gen3_logs_curljson" "non json output from $path"
    cat "$tempFile" 1>&2
  fi
  rm "$tempFile"
  return $result
}


GEN3_AGGS_DAILY="gen3-aggs-daily"


gen3_logs_fetch_aggs() {
  local aggsFile
  if [[ $# -lt 1 || ! -f "$1" ]]; then
    gen3_log_err "gen3_logs_fetch_aggs" "must pass aggs file to output results to"
    return 1
  fi
  aggsFile="$1"

  gen3_logs_rawlog_search "aggs=yes" "vpc=all" "start=$dayArg 00:00" "end=$dayArg + 1 day 00:00" > "$aggsFile"
  gen3_log_info "gen3_logs_fetch_aggs" "verifying query results ..."
  cat "$aggsFile" 1>&2
  # this will fail if the data is not json
  jq -e -r . > /dev/null 2>&1 < "$aggsFile"
}

#
# Save per-commons aggregations for yesterday
#
# @param dayDate defaults to yesterday
#
gen3_logs_save_daily() {
  local dayDate
  local indexStatus
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
  indexStatus="$(gen3_logs_curl "$GEN3_AGGS_DAILY" -X HEAD | grep HTTP | awk '{ print $2 }')"
  if [[ "$indexStatus" != 200 ]]; then
    # setup aggregations index
    gen3_logs_curl200 "$GEN3_AGGS_DAILY" -X PUT -d'
{
    "mappings": {
      "infodoc": {
        "properties": {
          "vpc_id": { "type": "keyword" },
          "hostname": { "type": "keyword" }
          "day_date": { "type": "date" },
          "unique_users": { "type": "integer" }
        }
      }
    }
}
'
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
  if ! gen3_retry gen3_logs_fetch_aggs "$aggsFile"; then
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
      # update the document
      if ! gen3_retry gen3_logs_curl200 "$GEN3_AGGS_DAILY/infodoc/${docId}?pretty=true" -i -X PUT "-d@$docFile" 1>&2; then
        gen3_logs_err "gen3_logs_save_daily" "failed to save user count for vpc $vpcName"
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
  startDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg start "$(gen3_logs_fix_date 'yesterday 00:00')" "$@")")"
  endDate="$(gen3_logs_fix_date "$(gen3_logs_get_arg end "$(gen3_logs_fix_date 'tomorrow 00:00')" "$@")")"
  pageNum="$(gen3_logs_get_arg page 0 "$@")"
  fromNum=$(($pageNum * 1000))
  
  queryFile="$(mktemp "$XDG_RUNTIME_DIR/esquery.json_XXXXXX")"
  cat - > "$queryFile" <<EOM
{
  "from": ${fromNum},
  "size": 1000,
  "sort": [
    {"day_date.keyword": "asc"},
    {"vpc_id.keyword": "asc"}
  ],
  "query": {
    "bool": {
      "must": [
        $(
          if [[ "$vpcName" != all ]]; then
            cat - <<ENESTED
            {"term": {"vpc_id.keyword": "$vpcName"}},
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
            "day_date.keyword": {
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

gen3_logs_user_list() {
  echo "SELECT 'uid:'||id,email FROM \"User\" WHERE email IS NOT NULL;" | gen3 psql fence --no-align --tuples-only --pset=fieldsep=,
}

gen3_logs_help() {
  gen3 help logs
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
    gen3_logs_help
    exit 0
  fi
  command="$1"
  shift
  case "$command" in
    "curl")
      gen3_logs_curl "$@"
      ;;
    "curl200")
      gen3_logs_curl200 "$@"
      ;;
    "curljson")
      gen3_logs_curljson "$@"
      ;;
    "raw")
      gen3_logs_rawlog_search "$@"
      ;;
    "rawq")  # echo raw query - mostly for test suite
      gen3_logs_rawlog_query "$@"
      ;;
    "user")
      gen3_logs_user_list "$@"
      ;;
    "vpc")
      gen3_logs_vpc_list "$@"
      ;;
    "save")
      subcommand=""
      if [[ $# -gt 0 ]]; then
        subcommand="$1"
        shift
      fi
      case "$subcommand" in
        "daily")
          gen3_logs_save_daily "$@"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid save subcommand $subcommand"
          ;;
      esac
      ;;
    "history")
      subcommand=""
      if [[ $# -gt 0 ]]; then
        subcommand="$1"
        shift
      fi
      case "$subcommand" in
        "daily")
          gen3_logs_history_daily "$@"
          ;;
        *)
          gen3_log_err "gen3_logs" "invalid history subcommand $subcommand"
          ;;
      esac
      ;;
    *)
      gen3_log_err "gen3_logs" "invalid command $command"
      gen3_logs_help
      ;;
  esac
fi
