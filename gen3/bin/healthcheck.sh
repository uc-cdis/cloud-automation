#
# TODO: write info here
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help healthcheck
}

gen3_healthcheck() {
  # refer to k8s api docs for pod status info
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#podstatus-v1-core
  local allPods=$(kubectl get pods -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.generateName, phase: .status.phase, reason: .status.reason,
        created: .metadata.creationTimestamp, waitingContainers: [ .status.containerStatuses[] | { state: .state, ready:.ready} ]
      }
    ]')
  local evictedPods=$(echo $allPods | jq -r '.[] | select(.reason == "Evicted")')
  local pendingPods=$(echo $allPods | jq -r '.[] | select(.phase == "Pending")')
  local unknownPods=$(echo $allPods | jq -r '.[] | select(.phase == "Unknown")')
  local crashLoopPods=$(echo $allPods | jq -r '.[] | select( .waitingContainers[].state.waiting.reason == "CrashLoopBackOff")')
  local terminatingPods='[]'
  local pendingLongPods='[]'

  # check for pods pending for more than 10 minutes
  while read -r pod; do
    local podDate=$(echo $pod | jq '.created')
    local startTime=$(date --date='$podDate' '+%s')
    if [[ $(( $(date '+%s') - $startTime )) -gt 600 ]]; then
      pendingLongPods=$(echo $pendingLongPods | jq -r '.[] += $pod')
    fi
  done <<< "$(echo $pendingPods | jq -c '.[]')"

  # check for terminating pods
  # Unfortunately the only way to get termination duration is by grepping the `describe` output
  while read -r pod; do
    local statusLine=$(echo $pod | jq -r '.name' | xargs kubectl describe pod | grep "Status:" -m 1)
    if [[ "$(echo $statusLine | awk '{ print $2 }')" == "Terminating" ]]; then
      # check how long it's been terminating
      local s=$(echo $statusLine | grep -oP "\d+(?=s)")
      local m=$(echo $statusLine | grep -oP "\d+(?=m)")
      local h=$(echo $statusLine | grep -oP "\d+(?=m)")
      if [[ $m -gt 10 || $s -gt 300 || $h -gt 0 ]]; then
        terminatingPods=$(echo $terminatingPods | jq -r '.[] += $pod')
      fi
    fi
  done <<< "$(echo $allPods | jq -c '.[]')"

  # check status of nodes
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#nodestatus-v1-core
  local allNodes=$(kubectl get nodes -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.labels."kubernetes.io/hostname", conditions: [ .status.conditions[] | { (.type): .status }] | add
      }
    ]')
  local notReadyNodes=$(echo $allNodes | jq -r '.[] | select(.conditions.Ready != "True")')

  # check internet access
  local statusCode=$(curl -s -o /dev/null -I -w "%{http_code}" https://www.google.com)
  local internetAccess=true
  if [[ $statusCode -lt 200 || $statusCode -ge 400 ]]; then
    internetAccess=false
  fi


  # Echo all the bad stuff
  # TODO: Check and report these values in better way
  echo "Pods pending > 10min: $pendingLongPods"
  echo "Pods terminating > 10min: $terminatingPods"
  echo "Pods unknown: $unknownPods"
  echo "Pods crashing: $crashLoopPods"
  echo "Pods evicted: $evictedPods"
  echo "Internet access available: $internetAccess"
}
