#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


#export GEN3_PROMHOST="${GEN3_PROMHOST:-"http://prometheus-server.prometheus.svc.cluster.local"}"
export GEN3_PROMHOST="${GEN3_PROMHOST:-"http://prometheus-operated.monitoring.svc.cluster.local:9090"}"

gen3_prom_help() {
  gen3 help prometheus
}

function gen3_prom_curl() {
  local urlBase="$1"
  shift || return 1
  local hostOrKey="${1:-${GEN3_PROMHOST}}"
  local urlPath="api/v1/$urlBase"
    
  if [[ "$hostOrKey" =~ ^http ]]; then
    gen3_log_info "fetching $hostOrKey/$urlPath"
    curl -s -H 'Accept: application/json' "$hostOrKey/$urlPath"
  else
    gen3 api curl "$urlPath" "$hostOrKey"
  fi
}

#
# Run a given prometheus query against the given gen3 host or key.
# If the hostOrKey starts with `http`, then we assume it is a URL prefix
# that we curl directly, otherwise we curl through `gen3 api curl`
#
# @param query
# @param hostOrKey defaults to $GEN3_PROMHOST 
#
function gen3_prom_query() {
  local query="$1"
  if ! shift || [[ -z "$query" ]]; then
    gen3_log_err "use: gen3_prom_query query"
    return 1
  fi
  gen3_prom_curl "query?query=$(gen3_encode_uri_component "$query")" "$@"
}

gen3_prom_list() {
  gen3_prom_curl "label/__name__/values" "$@"
}


if [[ -z "$1" || "$1" =~ ^-*help$ ]]; then
  gen3_prom_help
  exit 0
fi

command="$1"
shift

case "$command" in
"curl")
  gen3_prom_curl "$@"
  ;;
"query")
  gen3_prom_query "$@"
  ;;
"list")
  gen3_prom_list "$@"
  ;;
*)
  gen3_prom_help
  exit 1
  ;;
esac
