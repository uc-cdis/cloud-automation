
#
# Snapshot logs from a particular container of a particular pod
# to a .log.gz file
#
# @param pod
# @param container
# @param folder
# @return echo the path to the generated .log.gz file
#
gen3_logs_snapshot_container() {
  local podName
  local containerName

  if [[ $# -lt 1 ]]; then
    gen3_log_err "must pass podName argument, containerName is optional"
    return 1
  fi
  podName="$1"
  shift
  containerName=""
  if [[ $# -gt 0 ]]; then
    containerName="$1"
    shift
  fi
  local fileName
  fileName="${podName}.${containerName}.log"
  if g3kubectl logs "$podName" -c "$containerName" --limit-bytes 250000 > "$fileName" && gzip -f "$fileName"; then
    echo "${fileName}.gz"
    return 0
  fi
  return 1
}

#
# Snapshot all the pods
#
gen3_logs_snapshot_all() {
  # For each pod for which we can list the containers, get the pod name and get its list of containers
  # (container names + initContainers names). Diplay them as lines of "<pod name>  <container name>".
  g3kubectl get pods -o json | \
    jq -r '.items | map(select(.status.phase != "Pending" and .status.phase != "Unknown")) | map( {pod: .metadata.name, containers: [(.spec.containers | select(.!=null) | map(.name)), (.spec.initContainers | select(.!=null) | map(.name)) | add ] } ) | map( .pod as $pod | .containers | map( { pod: $pod, cont: .})[]) | map(select(.cont != "pause" and .cont != "jupyterhub"))[] | .pod + "  " + .cont' | \
    while read -r line; do
      gen3_logs_snapshot_container $line
    done
}
