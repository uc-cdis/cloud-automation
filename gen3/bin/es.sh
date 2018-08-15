#!/bin/bash
#
# Little elastic-search helper
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  cat - <<EOM
gen3 es indices
  list the elastic search indices
gen3 es dump index-name
  dump the contents of an ES index (ex: arranger-projects)
EOM
}


if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
  help
  exit 0
fi

command="$1"
shift

case "$command" in
"indices")
  gen3 devterm 'source gen3-arranger/Docker/Stacks/esearch/indexSetup.sh; export ESHOST=esproxy-service:9200; es_indices'
  ;;
"dump")
  indexName="$1"
  if [[ -z "$indexName" ]]; then
    help
    exit 1
  fi
  gen3 devterm "source gen3-arranger/Docker/Stacks/esearch/indexSetup.sh; export ESHOST=esproxy-service:9200; es_dump '$indexName'"
  ;;
"*")
  help
  exit 1
  ;;
esac
