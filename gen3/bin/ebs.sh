#/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib -----------------------

gen3_ebs_help() {
  gen3 help ebs
}

# Lists ebs volumes
gen3_ebs_list_volumes() {
  (
    gen3 aws ec2 describe-volumes
  )
}

# Lists ebs snapshots
gen3_ebs_list_snapshots() {
  (
    gen3 aws ec2 describe-snapshots
  )
}

# Takes a snapshot of an ebs volume
gen3_ebs_snapshot() {
  local volume
  local snapshot
  local status
  local state
  local progress
  local check
  volume="$1"
  if [[ -z "$volume" ]]; then
    gen3_log_err "Use: gen3 ebs snapshot <volume>"
    return 1
  fi
  if [[ -z "$volume" ]]; then
    gen3_log_info "Use: gen3 ebs snapshot volume"
    return 1
  fi
  (
    set -e
    check=$(aws ec2 describe-volumes --volume-id $volume| jq -r .Volumes[0])
    if [[ -z $check ]]; then
      gen3_log_err "Unable to find volume with is $volume"
      exit 1
    fi
    snapshot=$(gen3 aws ec2 create-snapshot --volume-id $volume | jq -r .SnapshotId)
    gen3_log_info "Found volume $volume taking snapshot"
    while [ "$state" != "completed" ]; do
      sleep 2s
      status=$(gen3 aws ec2 describe-snapshots --snapshot-id $snapshot)
      state=$(echo $status | jq -r  .Snapshots[0].State)
      progress=$(echo $status | jq -r .Snapshots[0].Progress)
      gen3_log_info "waiting on snapshot to finish being taken current progress is $progress"
    done
    gen3_log_info  "Snapshot complete"
    gen3_log_info "Snapshot ID: $snapshot"
    echo $snapshot
  )
}

# Restores ebs volume from snapshot
gen3_ebs_restore() {
  local snapshot
  local volume
  local zone
  local check
  local status
  snapshot=$1
  shift
  zone=$1
  if [[ -z "$snapshot" ]]; then
    gen3_log_err "Use: gen3 ebs restore <snapshot> <zone>"
    return 1
  fi
  if [[ -z "$zone" ]]; then
    gen3_log_err "Use: gen3 ebs restore <snapshot> <zone>"
    return 1
  fi
  (
    set -e
    check=$(gen3 aws ec2 describe-snapshots --snapshot-id $snapshot| jq -r .Snapshots[0])
    if [[ -z $check ]]; then
      gen3_log_err "Unable to find snapshot with id $snapshot"
      exit 1
    fi
    volume=$(gen3 aws ec2 create-volume --availability-zone $zone --snapshot-id $snapshot| jq -r .VolumeId)
    gen3_log_info "Found snapshot $snapshot creating volume"
    while [ "$state" != "available" ]; do
      sleep 2s
      status=$(gen3 aws ec2 describe-volumes --volume-id $volume)
      state=$(echo $status | jq -r  .Volumes[0].State)
      progress=$(echo $status | jq -r .Volumes[0].Progress)
      gen3_log_info "waiting on volume to be created"
    done
    gen3_log_info "Restore complete"
    gen3_log_info "Volume ID: $volume"
    echo $volume
  )
}

# Copies a volume to a specified zone
gen3_ebs_migrate() {
  local zone
  local volume
  local newVol
  volume=$1
  shift
  zone=$1
  if [[ -z "$volume" ]]; then
    gen3_log_err "Use: gen3 ebs migrate <volume> <zone>"
    return 1
  fi
    if [[ -z "$zone" ]]; then
    gen3_log_err "Use: gen3 ebs migrate <volume> <zone>"
    return 1
  fi
  snapshot="$(gen3_ebs_snapshot $volume)"
  # check current zone
  gen3_log_info "Snapshot taken with id $snapshot"
  newVol=$(gen3_ebs_restore $snapshot $zone)
  gen3_log_info "Migrate complete"
  echo $newVol
}


# Migrates the jupyter ebs volumes to a specific zone
gen3_ebs_jupyter_migrate() {
  local snapshot
  local volume
  local zone
  local check
  local status
  local origZone
  zone=$1
  shift
  namespace=$1
  if [[ -z "$zone" ]]; then
    gen3_log_err "Use: gen3 ebs jupyter-migrate <zone>... (optional) <namespace>"
    return 1
  fi
  (
    set -e
    if [[ -z $namespace ]]; then
      list=$(gen3 aws ec2 describe-volumes --filter Name=tag:kubernetes.io/created-for/pvc/namespace,Values=jupyter-pods --filter Name=tag:kubernetes.io/cluster/$vpc_name,Values=owned | jq -r .Volumes[].VolumeId)
    else
      list="$(gen3 aws ec2 describe-volumes --filter Name=tag:kubernetes.io/created-for/pvc/namespace,Values=jupyter-pods-$namespace --filter Name=tag:kubernetes.io/cluster/$vpc_name,Values=owned | jq -r .Volumes[].VolumeId)"
    fi
    if [[ -z $list ]]; then
      gen3_log_err "There are no jupyter volumes in this namespace"
    fi
    while read line; do
      origZone=$(gen3 aws ec2 describe-volumes --volume-id $line | jq -r .Volumes[].AvailabilityZone)
      if [[ $origZone == $zone ]]; then
        gen3_log_info "$line already in region $zone"
      else
        gen3_log_info "$line in region $origZone migrating to $zone"
        volume="$(gen3_ebs_migrate $line $zone)"
      fi
      gen3_ebs_kubernetes_migrate $line $volume
      sleep 20s
    done < <(printf '%s\n' "$list")
    gen3_log_info "All volumes have been migrated to zone $zone. Updating"
    gen3_log_info "Volume ID: $volume"
  )
}

# Migrate the kubernetes Persistant Volumes by exporting current config then updating the list. Will need to run kubectl apply -f after
gen3_ebs_kubernetes_migrate() {
  local originalVolume
  local newVolume
  originalVolume=$1
  shift
  newVolume=$1
  if [[ ! -f ${GEN3_HOME}/pvList.yaml ]]; then
    gen3_log_info "pvList.yaml not created. Creating in ${GEN3_HOME}/pvList.yaml"
    kubectl get pv -o yaml --export > "${GEN3_HOME}/pvList.yaml"
  fi
  sed -i "s/${originalVolume}/${newVolume}/g" "${GEN3_HOME}/pvList.yaml"
  gen3_log_info "$originalVolume update to $newVolume in kubernetes config update config with"
}

# main -----------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  # Support sourcing this file for test suite
  command="$1"
  shift
  case "$command" in
    "snapshot")
      gen3_ebs_snapshot "$@"
      ;;
    "restore")
      gen3_ebs_restore "$@"
      ;;
    "list-snapshots")
      gen3_ebs_list_snapshots "$@"
      ;;
    "list-volumes")
      gen3_ebs_list_volumes "$@"
      ;;
    "migrate")
      gen3_ebs_migrate "$@"
      ;;
    "jupyter-migrate")
      gen3_ebs_jupyter_migrate "$@"
      ;;
    "kubernetes-migrate")
      gen3_ebs_kubernetes_migrate "$@"
      ;;
    *)
      gen3_ebs_help
      ;;
  esac
fi
