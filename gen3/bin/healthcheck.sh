#
# TODO: write info here
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help healthcheck
}

gen3_healthcheck() {
  local evictedPods=$(kubectl get pods -o json | \
    jq  '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted"))')
  local unknownPods=$(kubectl get pods --field-selector status.phase=Unknown -o json | jq '.items[]')
  local crashLoopPods=$(kubectl get pods --field-selector status.phase=CrashLoopBackOff -o json | jq '.items[]')
  local pendingPods=$(kubectl get pods --field-selector status.phase=Pending -o json | jq '.items[]')
}