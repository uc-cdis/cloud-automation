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
        return 1
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
        created: .metadata.creationTimestamp  ,
        waitingContainers: [ .status.containerStatuses // [] | .[] | { state: .state, ready:.ready} ]
      }
    ]')
  gen3_log_info "Checking pods..."
  local evictedPods=$(jq -r '[.[] | select(.reason == "Evicted") ]' <<<"$allPods")
  local pendingPods=$(jq -r '[.[] | select(.phase == "Pending")]' <<<"$allPods")
  local failedPods=$(jq -r '[.[] | select(.phase == "Failed")]' <<<"$allPods")
  local unknownPods=$(jq -r '[.[] | select(.phase == "Unknown")]' <<<"$allPods")
  local crashLoopPods=$(jq -r '[.[] | select( .waitingContainers[].state.waiting.reason == "CrashLoopBackOff")]' <<<"$allPods")
  local terminatingPods=$(g3kubectl get pods --all-namespaces | grep "Terminating" | awk '{ print "{ \"namespace\": \"" $1 "\", "; print "\"name\": \"" $2 "\"}"; }' | jq -r '[inputs]')
  local terminatingTimeoutPods='[]'
  local pendingTimeoutPods='[]'

  # check for pods pending for more than 10 minutes
  while read -r pod; do
    local podDate=$(jq -r '.created' <<< "$pod")
    local startTime=$(date --date="$podDate" '+%s')
    local secsPassed=$(( $(date '+%s') - $startTime ))
    if [[ $secsPassed -gt 600 ]]; then
      pendingTimeoutPods=$(jq -r ". += [$pod]" <<< "$pendingTimeoutPods")
    fi
  done <<< "$(jq -c '.[]' <<< "$pendingPods")"

  # check for terminating pods
  # Unfortunately the only way to get termination duration is by grepping the `describe` output
  gen3_log_info "Checking terminating pods for timeout..."
  while read -r pod; do
    if [[ -z "$pod" ]]; then continue; fi
    local statusLine=$(g3kubectl describe pod $(jq -r '.name' <<< "$pod") --namespace $(jq -r '.namespace' <<< "$pod") | grep "Status:" -m 1)
    if [[ "$(awk '{ print $2 }' <<< "$statusLine")" == "Terminating" ]]; then
      # check how long it's been terminating
      local s=$(grep -oP "\d+(?=s)" <<< "$statusLine")
      local m=$(grep -oP "\d+(?=m)" <<< "$statusLine")
      local h=$(grep -oP "\d+(?=h)" <<< "$statusLine")
      if [[ $m -gt 10 || $s -gt 300 || $h -gt 0 ]]; then
        terminatingTimeoutPods=$(jq -r ". += [$pod]" <<< "$terminatingTimeoutPods")
      fi
    fi
  done <<< "$(jq -c '.[]' <<< "$terminatingPods")"

  # check status of nodes
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#nodestatus-v1-core
  local allNodes=$(g3kubectl get nodes -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.labels."kubernetes.io/hostname", conditions: [ .status.conditions[] | { (.type): .status }] | add
      }
    ]')
  local notReadyNodes=$(jq -r '[.[] | select(.conditions.Ready != "True")]' <<< "$allNodes")

  # check internet access
  gen3_log_info "Checking internet access..."
  local curlCmd="curl --max-time 15 -s -o /dev/null -I -w %{http_code} https://www.google.com"
  local statusCode=0
  if [[ $HOSTNAME == *"admin"* ]]; then # if in admin vm, run curl in devterm
    statusCode=$(gen3 devterm -c $curlCmd)
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
  if [[ $HOSTNAME == *"admin"* ]]; then # inside adminvm, curl from devterm
    statusCodeExplicit=$(gen3 devterm -c env http_proxy=$http_proxy https_proxy=$http_proxy -- $curlCmd)
  else # not inside adminvm, curl from here
    statusCodeExplicit=$(
      export http_proxy=$http_proxy
      export https_proxy=$http_proxy
      $curlCmd
    )
  fi
  gen3_log_info "internet access by explicit proxy check got: $statusCodeExplicit"
  local internetAccessExplicitProxy=true
  if [[ "$statusCodeExplicit" -lt 200 || "$statusCodeExplicit" -ge 400 ]]; then
    internetAccessExplicitProxy=false
  fi

  local healthJson=$(cat - <<EOM
  {
    "pendingTimeoutPods": $pendingTimeoutPods,
    "terminatingTimeoutPods": $terminatingTimeoutPods,
    "failedPods": $failedPods,
    "unknownPods": $unknownPods,
    "crashLoopPods": $crashLoopPods,
    "evictedPods": $evictedPods,
    "notReadyNodes": $notReadyNodes,
    "internetAccess": $internetAccess,
    "internetAccessExplicitProxy": $internetAccessExplicitProxy
  }
EOM
  )

  if ! jq -r . <<<"$healthJson" > /dev/null; then
    gen3_log_err "failed to assemble valid json data: $healthJson"
    return 1
  fi
  local healthy=true
  local healthSimple=""
  for statusKey in failedPods pendingTimeoutPods terminatingTimeoutPods unknownPods crashLoopPods evictedPods notReadyNodes; do
    # ".${yyy} | to_entries[] | [.key, .value] | @tsv"
    local nameList=$(jq -r ".${statusKey}[] | [.namespace, .name] | @tsv" <<< "$healthJson")
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
    return $?
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
      local hostname="$(gen3 api hostname)"
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

clear_evicted_pods() {
  g3kubectl get pods -A -o json | jq '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted")) | "kubectl delete pods \(.metadata.name) -n \(.metadata.namespace)"' | xargs -n 1 bash -c  2> /dev/null || true
}

gen3_healthcheck "$@"

clear_evicted_pods
