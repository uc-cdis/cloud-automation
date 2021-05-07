#!/bin/bash
#
# Deploy the redis service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


if ! g3k_manifest_lookup .versions.redis 2> /dev/null; then
  gen3_log_info "kube-setup-redis exiting - redis service not in manifest"
  exit 0
fi

gen3 roll redis
g3kubectl apply -f "${GEN3_HOME}/kube/services/redis/redis.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
fi

gen3_log_info "The redis service has been deployed onto the kubernetes cluster"
