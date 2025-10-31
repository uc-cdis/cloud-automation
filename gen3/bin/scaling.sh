source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ---------------------

scaling_init() {
  if [[ -z "$HPA_ON" ]]; then
    if gen3 kube-setup-metrics check > /dev/null; then 
      HPA_ON=yes
    else
      HPA_ON=no
    fi
  fi
  echo "$HPA_ON"
}

#
# Dump the manifest-scaling configmap
# Note: load the map with `gen3 gitops configmaps`
#
scaling_rules() {
  if ! g3kubectl get configmaps manifest-scaling > /dev/null; then
    gen3_log_err "no scaling rules exist in manifest-scaling configmap - default to manual for all services"
    echo "{}"
    return 1
  fi
  g3kubectl get configmaps manifest-scaling -o json | jq -r .data.json
}

#
# Take a service or deployment name, and figure out the deployment name
#
# @param service or could be a deployment name
#
scaling_get_deployment_name() {
  local deploymentPath
  local deploymentName
  local serviceName

  serviceName="$1"
  shift
  
  if deploymentPath="$(gen3 gitops rollpath "$serviceName")"; then
    deploymentName="$(gen3 gitops filter "$deploymentPath" | yq -r .metadata.name)"
  else
    # assume we have been given a deployment name
    deploymentName="$serviceName"
  fi
  echo "$deploymentName"
}

#
# Set the replicas count on a deployment
#
# @param deploymentName or service alias
# @param replicaCount integer
#
scaling_replicas() {
  if [[ $# -lt 2 ]]; then
    gen3_log_err "use: replicas deployment-name replica-count"
    return 1
  fi
  local serviceName
  local replicaCount
  local deploymentName

  serviceName="$1"
  shift
  replicaCount="$1"
  shift

  deploymentName="$(scaling_get_deployment_name "$serviceName")"  
  g3kubectl patch deployment "$deploymentName" -p  '{"spec":{"replicas":'$replicaCount'}}' 1>&2
}

#
# Auto-generate an hpa rule for a service given certain variables
#
# @param deploymentName of target deploym, sheepdog, ...
# @param min pod count
# @param max pod count
# @param targetCPU target cpu utilization
#
scaling_hpa_template() {
  local app
  local deploymentName
  local min
  local max
  local targetCpu

  if [[ $# -lt 4 ]]; then
    gen3_log_err "scaling_hpa takes 4 arguments, but got: $@"
    return 1
  fi
  deploymentName="$1"
  shift
  min="$1"
  shift
  max="$1"
  shift
  targetCpu="$1"
  shift
  app="${deploymentName%-deployment}"
  
  cat - <<EOM
---
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: ${app}
  labels:
    app: ${app}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${deploymentName}
  minReplicas: ${min}
  maxReplicas: ${max}
  targetCPUUtilizationPercentage: ${targetCpu}
EOM
}

#
# Apply the given rule
#
scaling_apply_rule() {
  local rule="$1"
  gen3_log_info "Applying rule $rule"
  local service
  local strategy
  if ! service="$(jq -e -r .key <<<"$rule")"; then
    gen3_log_err "failed to determine scaling service"
    return 1
  fi
  if ! strategy="$(jq -e -r .value.strategy <<<"$rule")"; then
    gen3_log_err "failed to determine scaling strategy"
    return 1
  fi
  case "$strategy" in
    auto)
      local min
      local max
      local targetCpu
      if ! min="$(jq -e -r .value.min <<<"$rule")"; then
        min=2
        gen3_log_warn "no min scaling number - default to $min"
      fi
      if ! max="$(jq -e -r .value.max <<<"$rule")"; then
        max=$((min+6))
        gen3_log_warn "no max scaling number - default to $max"
      fi
      if ! targetCpu="$(jq -e -r .value.targetCpu <<<"$rule")"; then
        targetCpu=40
        gen3_log_warn "no target cpu - default to $targetCpu"
      fi
      # do like this rather than $(scaling_init) - which runs in sub-process
      scaling_init > /dev/null
      if [[ "$HPA_ON" == "yes" ]]; then
        # metrics-server is deployed, so deploy hpa (horizontal pod autoscaling) 
        local deploymentName="$(scaling_get_deployment_name "$service")"
        g3kubectl apply -f - <<<"$(scaling_hpa_template "$deploymentName" "$min" "$max" "$targetCpu")"
      else
        gen3_log_info "hpa metrics not available - patching replicas instead"
        scaling_replicas "$service" "$min"
      fi
      ;;
    manual)
      gen3_log_info "skipping manual scaling service: $service"
      return 0
      ;;
    pin)
      local num
      if ! num="$(jq -e -r .value.num <<<"$rule")"; then
        gen3_log_err "failed to determine scaling number"
        return 1
      fi
      scaling_replicas "$service" "$num"
      ;;
    *)
      gen3_log_err "unknown scaling strategy: $strategy"
      return 1
      ;;
  esac
}


#
# Load the scaling rules, and sync them with the cluster
#
scaling_apply_all() {
  local rulesMap
  if ! rulesMap="$(scaling_rules)"; then
    gen3_log_warn "failed to load scaling rules from manifest"
    return 1
  fi
  local rulesList="$(jq -r '. | to_entries' <<<"$rulesMap")"
  local index=0
  local numRules
  
  numRules="$(jq -r '. | length' <<<"$rulesList")"
  kubectl delete --all horizontalpodautoscalers.autoscaling > /dev/null
  for ((index=0; index < numRules; index++)); do
    scaling_apply_rule "$(jq -r --arg index $index '.[$index|tonumber]' <<<"$rulesList")"
  done
}

update_rules() {
  if [[ $# -lt 3 ]]; then
    gen3_log_err "use: update deployment-name min max (optional) targetCpu"
    return 1
  fi
  local deploymentName="$1-deployment"
  local min="$2"
  local max="$3"
  if [[ -z $4 ]]; then
    g3kubectl apply -f - <<<"$(scaling_hpa_template "$deploymentName" "$min" "$max" "40")"
  else
    g3kubectl apply -f - <<<"$(scaling_hpa_template "$deploymentName" "$min" "$max" "$4")"
  fi
}

#
# CLI processor
#
scaling_cli() {
  local command="$1"
  shift
  case "$command" in
      "rules")
        scaling_rules "$@"
        ;;
      "apply")
        local subCommand=""
        if [[ $# -gt 0 ]]; then
          subCommand="$1"
          shift
        fi
        case "$subCommand" in
          "all")
            scaling_apply_all "$@"
            ;;
          "rule")
            scaling_apply_rule "$@"
            ;;
          *)
            gen3_log_err "use: gen3 scaling apply all|rule"
            gen3 help scaling
            exit 1
            ;;
        esac
        ;;
      "replicas")
        scaling_replicas "$@"
        ;;
      "update")
        update_rules "$@"
        ;;
      *)
        gen3_log_err "unknown scaling sub-command: $command"
        gen3 help scaling
        exit 2
        ;;
  esac
}

# main --------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  scaling_cli "$@"
fi
