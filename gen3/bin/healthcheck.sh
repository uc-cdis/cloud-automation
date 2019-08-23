#!/bin/bash
#
# Finds any unhealthy pods and nodes
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help healthcheck
}

getPodsSimple() {
  g3kubectl get pods "$@" -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.name, namespace: .metadata.namespace, phase: .status.phase, reason: .status.reason,
        created: .metadata.creationTimestamp, waitingContainers: [ .status.containerStatuses[] | { state: .state, ready:.ready} ]
      }
    ]'
}

gen3_healthcheck() {
  local HEALTH_SEND_SLACK=false
  local RETRY=false
  local RETRY_PARAMS=""
  while [[ $# -gt 0 ]]; do
    local key="$1"
    case $key in
      '--slack')
      	HEALTH_SEND_SLACK=true
        RETRY_PARAMS="${RETRY_PARAMS} --slack"
        shift
        ;;
      '--retry')
        RETRY=true
        shift
        ;;
      *)
        gen3_log_err "Unrecognized flag $key"
        help
        exit 1
        ;;
    esac
  done

  # refer to k8s api docs for pod status info
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#podstatus-v1-core
  gen3_log_info "Getting all pods..."
  local allPods=$(g3kubectl get pods --all-namespaces -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.name, namespace: .metadata.namespace, phase: .status.phase, reason: .status.reason,
        created: .metadata.creationTimestamp, waitingContainers: [ .status.containerStatuses[] | { state: .state, ready:.ready} ]
      }
    ]')
  gen3_log_info "Checking pods..."
  local evictedPods=$(echo $allPods | jq -r '[.[] | select(.reason == "Evicted") ]')
  local pendingPods=$(echo $allPods | jq -r '[.[] | select(.phase == "Pending")]')
  local unknownPods=$(echo $allPods | jq -r '[.[] | select(.phase == "Unknown")]')
  local crashLoopPods=$(echo $allPods | jq -r '[.[] | select( .waitingContainers[].state.waiting.reason == "CrashLoopBackOff")]')
  local terminatingPods=$(g3kubectl get pods --all-namespaces | grep "Terminating" | awk '{ print "{ \"namespace\": \"" $1 "\", "; print "\"name\": \"" $2 "\"}"; }' | jq -r '[inputs]')
  local terminatingTimeoutPods='[]'
  local pendingTimeoutPods='[]'

  # check for pods pending for more than 10 minutes
  while read -r pod; do
    local podDate=$(echo $pod | jq -r '.created')
    local startTime=$(date --date="$podDate" '+%s')
    local secsPassed=$(( $(date '+%s') - $startTime ))
    if [[ $secsPassed -gt 600 ]]; then
      pendingTimeoutPods=$(echo $pendingTimeoutPods | jq -r ". += [$pod]")
    fi
  done <<< "$(echo $pendingPods | jq -c '.[]')"

  # check for terminating pods
  # Unfortunately the only way to get termination duration is by grepping the `describe` output
  gen3_log_info "Checking terminating pods for timeout..."
  while read -r pod; do
    if [[ -z "$pod" ]]; then continue; fi
    local statusLine=$(g3kubectl describe pod $(echo $pod | jq -r '.name') --namespace $(echo $pod | jq -r '.namespace') | grep "Status:" -m 1)
    if [[ "$(echo $statusLine | awk '{ print $2 }')" == "Terminating" ]]; then
      # check how long it's been terminating
      local s=$(echo $statusLine | grep -oP "\d+(?=s)")
      local m=$(echo $statusLine | grep -oP "\d+(?=m)")
      local h=$(echo $statusLine | grep -oP "\d+(?=h)")
      if [[ $m -gt 10 || $s -gt 300 || $h -gt 0 ]]; then
        terminatingTimeoutPods=$(echo $terminatingTimeoutPods | jq -r ". += [$pod]")
      fi
    fi
  done <<< "$(echo $terminatingPods | jq -c '.[]')"

  # check status of nodes
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#nodestatus-v1-core
  local allNodes=$(g3kubectl get nodes -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.labels."kubernetes.io/hostname", conditions: [ .status.conditions[] | { (.type): .status }] | add
      }
    ]')
  local notReadyNodes=$(echo $allNodes | jq -r '[.[] | select(.conditions.Ready != "True")]')

  # check internet access
  gen3_log_info "Checking internet access..."
  local curlCmd="curl --max-time 15 -s -o /dev/null -I -w %{http_code} http://www.google.com"
  local statusCode=0
  if [[ $HOSTNAME == *"admin"* ]]; then # if in admin vm, run curl in fence pod
    statusCode=$(g3kubectl exec $(gen3 pod fence) -- $curlCmd)
  else # not inside adminvm, curl from here
    statusCode=$($curlCmd)
  fi
  local internetAccess=true
  gen3_log_info "internet access check got: $statusCode"
  if [[ "$statusCode" -lt 200 || "$statusCode" -ge 400 ]]; then
    internetAccess=false
  fi
 
  # check internet access with explicit proxy
  gen3_log_info "Checking explicit proxy internet access..."
  local http_proxy="http://cloud-proxy.internal.io:3128"
  local statusCodeExplicit=0
  if [[ $HOSTNAME == *"admin"* ]]; then # inside adminvm, curl from fence pod
    statusCodeExplicit=$(g3kubectl exec $(gen3 pod fence) env http_proxy=$http_proxy https_proxy=$http_proxy -- $curlCmd)
  else # not inside adminvm, curl from here
    statusCodeExplicit=$(
      export http_proxy=$http_proxy
      export https_proxy=$http_proxy
      $curlCmd
    )
  fi
  gen3_log_info "internet access by explicity proxy check got: $statusCodeExplicit"
  local internetAccessExplicitProxy=true
  if [[ "$statusCodeExplicit" -lt 200 || "$statusCodeExplicit" -ge 400 ]]; then
    internetAccessExplicitProxy=false
  fi

  local healthJson=$(echo '{}' | jq -r "{
    pendingTimeoutPods: $pendingTimeoutPods,
    terminatingTimeoutPods: $terminatingTimeoutPods,
    unknownPods: $unknownPods,
    crashLoopPods: $crashLoopPods,
    evictedPods: $evictedPods,
    notReadyNodes: $notReadyNodes,
    internetAccess: $internetAccess,
    internetAccessExplicitProxy: $internetAccessExplicitProxy
  }")

  local healthy=true
  local healthSimple=""
  for statusKey in pendingTimeoutPods terminatingTimeoutPods unknownPods crashLoopPods evictedPods notReadyNodes; do
    # ".${yyy} | to_entries[] | [.key, .value] | @tsv"
    local nameList=$(echo $healthJson | jq -r ".${statusKey}[] | [.namespace, .name] | @tsv")
    if [[ ! -z "$nameList" ]]; then
      healthy=false
      healthSimple="${healthSimple}\n*${statusKey}*\n${nameList}"
    fi
  done
  if [[ "$internetAccess" == false || "$internetAccessExplicitProxy" == false ]]; then
    healthy=false
  fi
  healthSimple="${healthSimple}\n\n*internetAccess*	$internetAccess\n\n*internetAccessExplicitProxy*	$internetAccessExplicitProxy\n"

  if [[ "$RETRY" = true && "$healthy" = false ]]; then
    jq -r '.' <<< "$healthJson" 1>&2
    gen3_log_info "Unhealthy. Waiting for 30 seconds then trying again..."
    sleep 30
    gen3_healthcheck $RETRY_PARAMS
    exit $?
  fi

  # print final result to stdout
  jq -r '.' <<< "$healthJson"

  if [[ "$HEALTH_SEND_SLACK" = true && "$healthy" == false ]]; then
    if [[ "${slackWebHook}" == 'None' || -z "${slackWebHook}" ]]; then
      slackWebHook=$(g3kubectl get configmap global -o jsonpath={.data.slack_webhook})
    fi
    if [[ "${slackWebHook}" == 'None' || -z "${slackWebHook}" ]]; then
      gen3_log_err "WARNING: slackWebHook is None or doesn't exist; not sending results to Slack"
    else
      local hostname="$(g3kubectl get configmap manifest-global -o json | jq -r '.data.hostname')"
      local payload="$(cat - <<EOM
payload={
  "text": ":warning: Healthcheck failed for ${hostname}",
  "attachments": [
    {"title": "Statuses", "text": "$healthSimple", "color": "#FF0000", "mrkdwn_in": ["text"] }
  ]
}
EOM
)"
      gen3_log_info "slack payload: $payload"
      curl --max-time 15 -X POST --data-urlencode "${payload}" "${slackWebHook}" 1>&2
    fi
  fi
}

gen3_healthcheck "$@"
