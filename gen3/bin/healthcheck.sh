#!/bin/bash
#
# Finds any unhealthy pods and nodes
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

help() {
  gen3 help healthcheck
}

gen3_healthcheck() {
  local HEALTH_SEND_SLACK=false
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      '--slack')
	HEALTH_SEND_SLACK=true
	shift
	;;
      *)
	echo "Unrecognized flag"
	help
	exit 1
	;;
    esac
  done

  # refer to k8s api docs for pod status info
  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#podstatus-v1-core
  local allPods=$(g3kubectl get pods -o json | \
    jq -r '[
      .items[] | {
        name: .metadata.generateName, phase: .status.phase, reason: .status.reason,
        created: .metadata.creationTimestamp, waitingContainers: [ .status.containerStatuses[] | { state: .state, ready:.ready} ]
      }
    ]')

  local evictedPods=$(echo $allPods | jq -r '[.[] | select(.reason == "Evicted") ]')
  local pendingPods=$(echo $allPods | jq -r '[.[] | select(.phase == "Pending")]')
  local unknownPods=$(echo $allPods | jq -r '[.[] | select(.phase == "Unknown")]')
  local crashLoopPods=$(echo $allPods | jq -r '[.[] | select( .waitingContainers[].state.waiting.reason == "CrashLoopBackOff")]')
  local terminatingPods='[]'
  local pendingLongPods='[]'

  # check for pods pending for more than 10 minutes
  while read -r pod; do
    local podDate=$(echo $pod | jq -r '.created')
    local startTime=$(date --date="$podDate" '+%s')
    local secsPassed=$(( $(date '+%s') - $startTime ))
    if [[ $secsPassed -gt 600 ]]; then
      pendingLongPods=$(echo $pendingLongPods | jq -r ". += [$pod]")
    fi
  done <<< "$(echo $pendingPods | jq -c '.[]')"

  # check for terminating pods
  # Unfortunately the only way to get termination duration is by grepping the `describe` output
  while read -r pod; do
    local statusLine=$(g3kubectl describe pod $(echo $pod | jq -r '.name') | grep "Status:" -m 1)
    if [[ "$(echo $statusLine | awk '{ print $2 }')" == "Terminating" ]]; then
      # check how long it's been terminating
      local s=$(echo $statusLine | grep -oP "\d+(?=s)")
      local m=$(echo $statusLine | grep -oP "\d+(?=m)")
      local h=$(echo $statusLine | grep -oP "\d+(?=h)")
      if [[ $m -gt 10 || $s -gt 300 || $h -gt 0 ]]; then
        terminatingPods=$(echo $terminatingPods | jq -r ". += [$pod]")
      fi
    fi
  done <<< "$(echo $allPods | jq -c '.[]')"

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
  local curlCmd="curl -s -o /dev/null -I -w "%{http_code}" https://www.google.com"
  if [[ $HOSTNAME == *"admin"* ]]; then
    curlCmd="g3kubectl exec $(get_pod fence) -- $curlCmd"
  fi
  local statusCode=$(eval $curlCmd)
  local internetAccess=true
  if [[ $statusCode -lt 200 || $statusCode -ge 400 ]]; then
    internetAccess=false
  fi
  (
    export http_proxy="http://cloud-proxy.internal.io:3128"
    export https_proxy=$http_proxy
    local statusCodeExplicit=$(curl -s -o /dev/null -I -w "%{http_code}" https://www.google.com)
    if [[ $statusCodeExplicit -lt 200 || $statusCodeExplicit -ge 400 ]]; then
      exit 1
    else
      exit 0
    fi
  )
  explicitProxyResult=$?
  local internetAccessExplicitProxy=true
  if [[ $explicitProxyResult != 0 ]]; then
    internetAccessExplicitProxy=false
  fi

  local healthy=true
  if [[ "$internetAccess" = false || "$internetAccessExplicitProxy" = false || "$pendingLongPods" != "[]" || "$terminatingPods" != "[]" || "$unknownPods" != "[]" || "$crashLoopPods" != "[]" || "$evictedPods" != "[]" || "$notReadyNodes" != "[]" ]]; then
    healthy=false
  fi

  local healthJson=$(echo '{}' | jq -r "{
    pendingTimeoutPods: $pendingLongPods,
    terminatingTimeoutPods: $terminatingPods,
    unknownPods: $unknownPods,
    crashLoopBackOffPods: $crashLoopPods,
    evictedPods: $evictedPods,
    notReadyNodes: $notReadyNodes,
    internetAccess: $internetAccess,
    internetAccessExplicitProxy: $internetAccessExplicitProxy
  }")
  echo $healthJson | jq -r '.'

  if [[ "$HEALTH_SEND_SLACK" = true && "$healthy" = false ]]; then
    if [[ "${slackWebHook}" == 'None' || -z "${slackWebHook}" ]]; then
      slackWebHook=$(g3kubectl get configmap global -o jsonpath={.data.slack_webhook})
    fi
    if [[ "${slackWebHook}" == 'None' || -z "${slackWebHook}" ]]; then
      echo "WARNING: slackWebHook is None or doesn't exist; not sending results to Slack"
    else
      local tmpHostname=$(g3kubectl get configmap manifest-global -o jsonpath={.data.hostname})
      local formattedAttachment="{\"title\": \"Status\", \"text\": \"$(echo $healthJson | sed s/\"/\\\\\"/g | sed s/,/,\\n/g)\", \"color\": \"#FF0000\"}"
      curl -X POST --data-urlencode "payload={\"text\": \"Healthcheck FAILED for ${tmpHostname}\n\", \"attachments\": [$formattedAttachment]}" "${slackWebHook}"
    fi
  fi
}

gen3_healthcheck "$@"
