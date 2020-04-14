#!/bin/bash
#
# Launch a terminal or cli command onto the kubernetes cluster
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if [[ -n "$1" && "$1" =~ ^-*help$ ]]; then
  cat - <<EOM
gen3 devterm [command]
  Open an interactive bash shell on the kubernetes cluster or pass the given command to the bash shell
EOM
  exit 0
fi

overrides='{}'
if g3kubectl get serviceaccounts/jenkins-service > /dev/null 2>&1; then
  gen3_log_info "devterm" "mounting jenkins service account"
  overrides='{ "spec": { "serviceAccountName": "jenkins-service" }}'
fi

# some command line processing
image=quay.io/cdis/awshelper:master
labels="app=gen3job,name=devterm,netnolimit=yes"
pullPolicy="IfNotPresent"
declare -a command=("/bin/bash")
while [[ $# -gt 0 ]]; do
  case "$1" in
    -*labels)
      shift
      labels="$1"
      shift
      continue
      ;;
    -c)
      shift
      continue
      ;;
    --*command)
      shift
      continue
      ;;
    --*pull)
      shift
      pullPolicy="Always"
      continue
      ;;
    --*image)
      shift
      image="$1"
      shift
      continue
      ;;
    sh)
      command=(sh)
      shift
      continue
      ;;
    /bin/sh)
      command=(/bin/sh)
      shift
      continue
      ;;
    -*)
      command+=("$1")
      shift
      continue
      ;;
    *)
      command+=("-c" "$*")
      break
      ;;
  esac
done
gen3_log_info "devterm" "running $image with labels $labels command ${command[@]}"
gen3_log_info g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --overrides "$overrides" --labels="$labels" --restart=Never --image=$image --image-pull-policy=$pullPolicy --command -- "${command[@]}"
g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --overrides "$overrides" --labels="$labels" --restart=Never --image=$image --image-pull-policy=$pullPolicy --command -- "${command[@]}"
