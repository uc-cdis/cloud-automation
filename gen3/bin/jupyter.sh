source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


# lib --------------------------

# 
# Extend the prepuller yaml with data from the manifest
#
# @param varargs img1 img2 ... - additional images as args - mostly to support testing
#
gen3_jupyter_prepuller() {
  local images
  local it
  images="$@"
  if g3kubectl get configmap manifest-jupyterhub > /dev/null 2>&1; then
    images="$images $(g3kubectl get configmap manifest-jupyterhub -ojson | jq -r '.data.containers // "[]" | fromjson | map(.image) | .[]')"
  fi

  cat "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub-prepuller.yaml"
  if [[ -n "$images" ]]; then
    local count=0
    for it in ${images}; do
      cat - <<EOM
      - name: "image-${count}"
        image: $it
        imagePullPolicy: IfNotPresent
        command:
          - /bin/sh
          - -c
          - echo 'Pulling complete'
EOM
      count=$((count+1))
    done
  fi
}


#
# Echo the user namespace where jupyter notebooks run.
#
# @param gen3Namespace defaults to current namespace (gen3 db namespace)
#
gen3_jupyter_namespace() {
  local notebookNamespace
  local namespace="$(gen3 db namespace)"

  # If you change this name you need to change it in the hatchery configs too
  notebookNamespace="jupyter-pods"
  if [[ $# -gt 0 && -n "$1" ]]; then
    namespace="$1"
    shift
  fi
  if [[ -n "$namespace" && "$namespace" != "default" ]]; then
    notebookNamespace="jupyter-pods-$namespace"
  fi
  echo "$notebookNamespace"
}

#
# Create and label the jupyter namespace, also label the gen3 workspace
#
gen3_jupyter_namespace_setup() {
  local notebookNamespace
  local namespace
  
  # avoid doing this overly often
  if gen3_time_since jupyter_setup is 300; then
    namespace="$(gen3 db namespace)"
    notebookNamespace="$(gen3_jupyter_namespace)"

    if ! g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
      gen3_log_info "gen3_jupyter_namespace_setup" "creating k8s namespace: ${notebookNamespace}" 
      g3kubectl create namespace "${notebookNamespace}"
    else
      gen3_log_info "gen3_jupyter_namespace_setup" "I think k8s namespace ${notebookNamespace} already exists"
    fi
    g3kubectl label namespace "${notebookNamespace}" "role=usercode" > /dev/null 2>&1 || true
    g3kubectl label namespace "${namespace}" "role=gen3" > /dev/null 2>&1 || true
  else
    gen3_log_info "Skipping jupyter namespace setup - already did it in last 5 minutes"
  fi
}


#
# Update the jupyterhub configmaps,
# update the prepuller, 
# and restart jupyter hub
#
gen3_jupyter_upgrade() {
  local notebookNamespace
  notebookNamespace="$(gen3_jupyter_namespace)"
  if ! g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
    gen3_log_err "gen3_jupyter_upgrade" "refusing to upgrade jupyter - namespace does not exist $notebookNamespace"
    return 1
  fi
  
  gen3 gitops configmaps
  gen3 update_config jupyterhub-config "${GEN3_HOME}/kube/services/jupyterhub/jupyterhub_config.py"

  if g3kubectl get statefulset jupyterhub-deployment; then 
    g3kubectl delete statefulset jupyterhub-deployment || true
  fi
  if g3kubectl get daemonset jupyterhub-prepuller; then
    g3kubectl delete daemonset jupyterhub-prepuller || true
  fi
  gen3 roll jupyterhub

  local namespace
  namespace="$(gen3 db namespace)"
  if [[ "$namespace" == "default" ]]; then
    # avoid deploying prepuller in dev/qa namespaces ...
    gen3_jupyter_prepuller | g3kubectl apply -f -
  fi
}

gen3_jupyter_pv_clear() {
  local grepFor
  local doIt="false"
  if [[ $# -lt 1 ]]; then
    gen3_log_err 'use: pvclear $grepFor -- just outputs a list of commands'
    return 1
  fi
  grepFor="$1"
  shift
  # grep for jupyter pods
  # note - this is building up an array/list
  local claims=($(g3kubectl get persistentvolumes | grep pods | grep "$grepFor" | awk '{ print $1 "  " $6 }'))
  local i
  local pv
  local pvc
  local pvcNamespace
  for ((i=0; i < "${#claims[@]}"; i+=2)); do
    pv="${claims[$i]}"
    pvc="$(awk -F / '{ print $1 }' <<<"${claims[$((i+1))]}")"
    pvcNamespace="$(awk -F / '{ print $2 }' <<<"${claims[$((i+1))]}")"

    gen3_log_info "$i" 
    gen3_log_info "g3kubectl delete persistentvolumeclaim --namespace $pvcNamespace $pvc"
    gen3_log_info "g3kubectl delete persistentvolume $pv"
  done
}


#
# Fetch a jupyter metric
#
# @param metricName [runtime|memory] default to "runtime"
# @param tokenKey default to ""
#
gen3_jupyter_metrics() {
  local metricName="runtime"
  local namespace
  local tokenKey
  jnamespace="$(gen3 jupyter j-namespace)" || return 1

  metricName="${1:-runtime}"
  if shift; then
    tokenKey="$1"
  fi
  local timeQuery='max_over_time(timestamp(kube_pod_status_phase{namespace="'"$jnamespace"'", phase="Running"} > 0)[24h:]) - ignoring(phase) max_over_time(kube_pod_start_time{namespace="'"$jnamespace"'"}[24h])'
  local memQuery='max_over_time(container_memory_usage_bytes{namespace="'"$jnamespace"'"}[24h])'
  local query="$timeQuery"

  if [[ "$metricName" == "memory" ]]; then
    query="$memQuery"
  fi

#promQuery='max_over_time(timestamp(kube_pod_status_phase{namespace="zlchitty", phase="Running"} > 0)[24h:])'
#promQuery2='max_over_time(kube_pod_start_time{namespace="zlchitty"}[24h])'
#promQuery3='max_over_time(timestamp(kube_pod_status_phase{namespace="zlchitty", phase="Running"} > 0)[24h:]) - ignoring(phase) max_over_time(kube_pod_start_time{namespace="zlchitty"}[24h])'
#promQuery4='max_over_time(container_memory_usage_bytes{namespace="zlchitty"}[24h])'

  gen3 prometheus query "$query" "$tokenKey"
}


#
# Try to identify the hatchery pods that have been idle for
# over 12 hours, so we can shut them down.
# This works by querying prometheus for the request rate
# handled by the ambassador reverse proxy that routes traffic
# to an app, so we usually to run this on the cluster to get the
# route out to prometheus.
#
# @param tokenKey either "none" if running on the cluster (can route directly to prometheus),
#      or a user or api-key where gen3 api curl /prometheus/... $tokenKey works
# @param namespace where ambassador is running - defaults to current namespace
# @param command defaults to list, also supports "kill"
# @see https://prometheus.io/docs/prometheus/latest/querying/examples/
#
gen3_jupyter_idle_pods() {
  local ttl=12h
  local namespace="$(gen3 db namespace)"
  local tokenKey="none"
  local command="list"

  if [[ $# -gt 0 ]]; then
    tokenKey="${1:-none}"
    shift
  fi
  if [[ $# -gt 0 ]]; then
    namespace="${1:-$namespace}"
    shift
  fi
  if [[ $# -gt 0 ]]; then
    command="${1:-$command}"
    shift
  fi

  # Get the list of idle ambassador clusters from prometheus
  local promQuery="sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{namespace=\"${namespace}\"}[${ttl}]))"
  local tempClusterFile="$(mktemp "$XDG_RUNTIME_DIR/idle_apps.json_XXXXXX")"
  gen3 prometheus query "$promQuery" "${tokenKey#none}" | jq -e -r '.data.result[] | { "cluster": .metric.envoy_cluster_name, "rate": .value[1] } | select(.rate == "0")' | tee "$tempClusterFile" 1>&2
  if [[ $? != 0 ]]; then
    gen3_log_info "no idle ambassadore clusters found"
    rm "$tempClusterFile"
    return 0
  fi
  
  # Get the list of app services in the user namespace
  local jnamespace="$(gen3_jupyter_namespace "$namespace")"
  local podList
  podList="$(g3kubectl get pods --namespace "$jnamespace" -o json | jq -r '.items[] | .metadata.name')" || return 1
  if [[ -z "$podList" ]]; then
    gen3_log_info "no pods found in namespace: $jnamespace"
    return 0
  fi
  for name in $podList; do
    # leverage hatchery pod/service naming convention here ...
    local serviceName="h-${name##hatchery-}-s"
    local clusterName="cluster_${serviceName//-/_}"
    #
    # there appears to be a 42 character limit on the ambassador cluster name:
    #    cluster_h_${serviceName//-/_}_${namespace}-${number}
    # , but '-${number}' is always there, so just match on the first say 39 chars
    #
    clusterName="$(cut -c -39 <<< "$clusterName")"
    gen3_log_info "Scanning for $clusterName"
    if jq -r --arg cluster "$clusterName" 'select(.cluster | startswith($cluster))' < "$tempClusterFile" | grep "$clusterName" > /dev/null; then
      echo "$name"
      if [[ "$command" == "kill" ]]; then
        pod_creation=$(date -d $(g3kubectl get pod "$name" -n "$jnamespace" -o jsonpath='{.metadata.creationTimestamp}') +%s)
        current_time=$(date +%s)
        age=$((current_time - pod_creation))

       # potential workspaces to be reaped for inactivity must be at least 60 minutes old
        if ((age >= 3600)); then
          gen3_log_info "try to kill pod $name in $jnamespace"
          g3kubectl delete pod --namespace "$jnamespace" "$name" 1>&2
        fi
      fi
    else
      gen3_log_info "$clusterName not in $(cat $tempClusterFile)"
    fi
  done
  rm "$tempClusterFile"
  return 0
}

# main ----------------------

command="$1"
shift
case "$command" in
  "j-namespace")
    if [[ $# -gt 0 && "$1" == "setup" ]]; then
      shift
      gen3_jupyter_namespace_setup "$@";
    else
      gen3_jupyter_namespace "$@";
    fi
    ;;
  "idle")
    gen3_jupyter_idle_pods "$@"
    ;;
  "metrics")
    gen3_jupyter_metrics "$@"
    ;;
  "prepuller")
    gen3_jupyter_prepuller "$@"
    ;;
  "upgrade")
    gen3_jupyter_upgrade "$@"
    ;;
  "pvclear")
    gen3_jupyter_pv_clear "$@"
    ;;
  *)
    gen3 help jupyter
    ;;
esac
exit $?
