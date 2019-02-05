#!/bin/bash
#
# Helper to query elastic search logs database
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

LOGHOST="${LOGHOST:-https://kibana.planx-pla.net}"
LOGUSER="${LOGUSER:-kibanaadmin}"
LOGPASSWORD="${LOGPASSWORD:-""}"

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
    "kfqa dcf-interop.kidsfirstdrc.org"
    "dcfprod nci-crdc.datacommons.io"
    "dcf-staging nci-crdc-staging.datacommons.io"
    "genomelprod genomel.bionimbus.org"
    "stageprod gen3.datastage.io"
    "vadcprod va.datacommons.io"
    "ibdgc-prod ibdgc.datacommons.io"
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
    echo -e "$(red_color "ERROR: LOGPASSWORD environment not set")" 1>&2
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
    echo -e "$(red_color "ERROR: invalid page $pageNum - setting to 0")" 1>&2
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
    curl -u "${LOGUSER}:${LOGPASSWORD}" -X GET "$LOGHOST/_all/_search?pretty=true" "-d@$queryFile" > $jsonFile
    rm "$queryFile"
    # check integrity of result
    errStr="$(jq -r .error < "$jsonFile")"
    if [[ "$errStr" != null ]]; then
      echo -e "$(red_color "ERROR: error from server")" 1>&2
      cat - 1>&2 <<EOM
$errStr
EOM
      cat "$jsonFile" 1>&2
      rm "$jsonFile"
      return 1
    fi
    if ! jq -r .hits.total > /dev/null 2>&1 < $jsonFile; then
      echo -e "$(red_color "ERROR: unable to parse search result")" 1>&2
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
    echo "INFO:, total_records=$totalRecs, pageSize=1000, pageMin=$pageMin, pageMax=$pageMax, lastPage=$pageIt" 1>&2
    let pageIt+=1
  done

  if [[ $pageIt -lt $pageMax && $pageMax -gt 10 ]]; then
    echo -e "$(red_color "Only retrieved $pageIt of $pageMax pages - 10000 record max result size")"
  fi
}


gen3_logs_aggs_24hr() {
  if [[ -z "$LOGPASSWORD" ]]; then
    echo -e "$(red_color "ERROR: LOGPASSWORD environment not set")" 1>&2
    return 1
  fi

cat - <<EOM
 "aggregations": {
    "unique_user_count" : {
        "cardinality" : {
            "field" : "message.user_id",
            "precision_threshold": 1000
        }
    }
  }
EOM
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
    "raw")
      gen3_logs_rawlog_search "$@"
      ;;
    "rawq")  # echo raw query - mostly for test suite
      gen3_logs_rawlog_query "$@"
      ;;
    "vpc")
      gen3_logs_vpc_list "$@"
      ;;
    "user")
      gen3_logs_user_list "$@"
      ;;
    *)
      echo -e "$(red_color "ERROR: invalid command $command")"
      gen3_logs_help
      ;;
  esac
fi
