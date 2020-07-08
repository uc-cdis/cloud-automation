#!/bin/bash
#
# Little elastic-search helper
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

export ESHOST="${ESHOST:-"esproxy-service:9200"}"

es_help() {
  gen3 help es
}


#
# Forward the esproxy-deployment port to localhost in a background process.
# Guard with a call to `ps uxwww` to check if port is already forwarded.
#
# @return echo the forwarded port
#
es_port_forward() {
  local portNum
  portNum="$(ps uxwwww | grep port-forward | grep 9200 | grep -v grep | sed 's/.* \([0-9]*\):9200/\1/')"
  if [[ -n "$portNum" ]]; then
    gen3_log_info "It looks like a port-forward process is already running"
  else
    local OFFSET
    OFFSET=$((RANDOM % 1000))
    portNum=$((OFFSET+9200))
    g3kubectl port-forward deployment/aws-es-proxy-deployment ${portNum}:9200 1>&2 &
  fi
  export ESHOST="localhost:$portNum"
  echo "$portNum"
}


#
# Dump the contents of a given index
#
# @parma indexName
#
function es_dump() {
  local indexName
  local size
  indexName=$1
  shift
  size="${1:-100}"

curl -s -X GET "${ESHOST}/${indexName}/_search?pretty=true&size=$size" \
-H 'Content-Type: application/json' -H 'Accept: application/json' -d'
{
  "query": { "match_all": {} }
}
'

}

#
# Get the list of indexes
#
function es_indices() {
  curl -s -X GET "${ESHOST}/_cat/indices?v"
}


#
# Create a new index
#
# @param index name
# @param mapping json file
#
es_create() {
  if [[ $# -lt 2 ]]; then
    gen3_log_err "use: es_create indexName mappingFile.json"
    return 1
  fi
  local name="$1"
  shift
  local mappingFile="$1"
  shift
  if [[ ! -f "$mappingFile" ]]; then
    gen3_log_err "mapping file does not exist: $mappingFile"
    return 1
  fi
  # Need to create arranger-projects index by hand
  curl -iv -X PUT "${ESHOST}/$name" -H 'Content-Type: application/json' -H 'Accept: application/json' "-d@$mappingFile"
}


#
# Delete a given index
#
function es_delete() {
  local name
  name="$1"
  if [[ -n "$name" ]]; then
    curl -iv -X DELETE "${ESHOST}/$name"
  else
    gen3_log_err 'Use: es_delete INDEX_NAME'
    return 1
  fi
}

#
# Dump the arranger config indexes to the given destination folder
# @param destFolder
# @param projectName name of the arranger project
#
function es_export() {
  local destFolder
  local projectName
  local indexList

  if [[ $# -lt 2 ]]; then
    gen3_log_err 'USE: es_export destFolderPath arrangerProjectName'
    return 1
  fi
  destFolder="$1"
  shift
  projectName="$1"
  shift
  mkdir -p "$destFolder"
  indexList=$(es_indices 2> /dev/null | grep "arranger-projects-${projectName}[- ]" | awk '{ print $3 }')
  for name in $indexList; do
    echo $name
    gen3 nrun elasticdump --input http://$ESHOST/$name --output ${destFolder}/${name}__data.json --type data
    gen3 nrun elasticdump --input http://$ESHOST/$name --output ${destFolder}/${name}__mapping.json --type mapping
  done
}


#
# Import the arranger config indexes dumped with es_export
# @param sourceFolder with the es_export files
# @param projectName name of the arranger project to import
#
function es_import() {
  local sourceFolder
  local projectName
  local indexList

  if [[ $# -lt 2 ]]; then
    gen3_log_err 'USE: es_import srcFolderPath arrangerProjectName'
    return 1
  fi

  sourceFolder="$1"
  shift
  projectName="$1"
  shift

  if es_indices | grep "arranger-projects-${projectName}[- ]" > /dev/null 2>&1; then
    gen3_log_err "arranger project already exists - abandoning import: $projectName"
    return 1
  fi

  #indexList="$(es_indices 2> /dev/null | grep arranger- | awk '{ print $3 }')"
  indexList=$(ls -1 $sourceFolder | sed 's/__.*json$//' | grep "arranger-projects-$projectName" | sort -u)
  local importCount
  importCount=0
  for name in $indexList; do
    gen3_log_info $name
    gen3 nrun elasticdump --output http://$ESHOST/$name --input $sourceFolder/${name}__mapping.json --type mapping
    gen3 nrun elasticdump --output http://$ESHOST/$name --input $sourceFolder/${name}__data.json --type data
    let importCount+=1
  done
  if [[ $importCount == 0 ]]; then
    gen3_log_err "no .json files found matching $projectName"
    return 1
  fi
  # make sure arranger-projects index has an entry for our project id
  if ! gen3 es indices | awk '{ print $3 }' | grep -e '^arranger-projects$' > /dev/null 2>&1; then
    # Need to create arranger-projects index by hand
    curl -iv -X PUT "${ESHOST}/arranger-projects" \
-H 'Content-Type: application/json' -H 'Accept: application/json' -d'
{
    "mappings" : {
      "arranger-projects" : {
        "properties" : {
          "active" : {
            "type" : "boolean"
          },
          "id" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "timestamp" : {
            "type" : "date"
          }
        }
      }
    }
}
';
  fi
  local dayStr
  dayStr="$(date +%Y-%m-%d)"
  curl -X PUT $ESHOST/arranger-projects/arranger-projects/$projectName?pretty=true \
    -H 'Content-Type: application/json' -H 'Accept: application/json' -d"
        {
          \"id\" : \"$projectName\",
          \"active\" : true,
          \"timestamp\" : \"${dayStr}T18:58:53.452Z\"
        }
";
}


#
# Point the given alias at the given index
#
# @param indexName
# @param aliasName
#
function es_alias() {
  local indexName
  local aliasName
  if [[ $# -lt 2 ]]; then
    local getPath
    getPath=$ESHOST/_aliases?pretty=true
    indexName="$1"
    if [[ -n "$indexName" ]]; then
      getPath="$ESHOST/$indexName/_alias?pretty=true"
    fi
    curl -X GET $getPath
    return $?
  fi
  indexName="$1"
  aliasName="$2"
  
  # Check if the alias already exists - if so, then remove it
  local existingAliases
  local oldName
  local removeExistingAliases
  removeExistingAliases=""
  existingKeys="$(curl -s -X GET $ESHOST/_aliases | jq -r "to_entries[] | select(.value.aliases[\"$aliasName\"]) | .key")"
  for oldName in $existingKeys; do
    removeExistingAliases="$removeExistingAliases
    { \"remove\" : { \"index\" : \"$oldName\", \"alias\" : \"$aliasName\" } },
    "
  done
  curl -X POST $ESHOST/_aliases \
   -H 'Content-Type: application/json' \
   -H 'Accept: application/json' \
   -d"
{
    \"actions\" : [
        $removeExistingAliases
        { \"add\" : { \"index\" : \"$indexName\", \"alias\" : \"$aliasName\" } }
    ]
}
"
}


#
# Get the mapping of a given index
#
# @param indexName
#
function es_mapping() {
  local indexName
  indexName=$1
  curl -X GET $ESHOST/${indexName}/_mapping?pretty=true
}

#
# Get the cluster health
#
function es_health() {
  curl -X GET $ESHOST/_cluster/health
}

#
# Get a list of garbage indices (see: gen3 help es)
#
function es_garbage() {
  # * select indices not referenced by an alias ignoring time_ aliases
  # * select indices that look like an ETL index: NAME_NUMBER
  # * group the remaining NAME_NUMBER indices by NAME, and remove the largest NUMBER index from each group
  # * return the remaining indices
  gen3 es 'alias' | jq -e -r '. | to_entries | map(.value = (.value.aliases | keys | map(select(. | test("^time_") | not)))) | map(select(.value | length == 0)) | map(select(.key | test("^[a-zA-Z].+_[0-9]+$"))) | map(.prefix = (.key | sub("_[0-9]+$"; "")) | .index = (.key | sub("^.+_"; "") | tonumber)) | group_by(.prefix) | map(sort_by(.index) | del(.[length - 1])[]) | .[].key'
}


if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
  es_help
  exit 0
fi

command="$1"
shift

case "$command" in
"alias")
  es_alias "$@"
  ;;
"indices")
  es_indices
  ;;
"create")
  es_create "$@"
  ;;
"delete")
  es_delete "$@"
  ;;
"dump")
  indexName="$1"
  if [[ -z "$indexName" ]]; then
    es_help
    exit 1
  fi
  es_dump "$@"
  ;;
"export")
  es_export "$@"
  ;;
"garbage")
  es_garbage "$@"
  ;;
"health")
  es_health "$@"
  ;;
"import")
  es_import "$@"
  ;;
"mapping")
  es_mapping "$@"
  ;;
"port-forward")
  es_port_forward
  ;;
*)
  es_help
  exit 1
  ;;
esac
