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


# some command line processing
image="$(g3k_config_lookup .versions.automation)" || image=quay.io/cdis/awshelper:master
labels="app=gen3job,name=devterm,netnolimit=yes"
pullPolicy="Always"
saName="jenkins-service"
namespace="$(gen3 api namespace)"
userName="${USER:-frickjack}@uchicago.edu"

declare -a command=("/bin/bash")
while [[ $# -gt 0 ]]; do
  case "$1" in
    -*labels)
      shift
      labels="$1"
      shift
      continue
      ;;
    -*namespace)
      shift
      namespace="$1"
      shift
      continue
      ;;
    -*sa)
      shift
      saName="$1"
      shift
      continue
      ;;
    -*user)
      shift
      userName="$1"
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
    --*nopull)
      shift
      pullPolicy="IfNotPresent"
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

overrides='{ "metadata":{ "annotations": { "gen3username": "'$userName'" }}, "spec": { "namespace": "'$namespace'" }}'
if g3kubectl --namespace "$namespace" get serviceaccounts $saName > /dev/null 2>&1; then
  gen3_log_info "mounting service account: $saName"
  overrides='{ "metadata":{ "annotations": { "gen3username": "'$userName'" }}, "spec": { "serviceAccountName": "'$saName'", "securityContext": { "fsGroup": 1000 } }}'
else
  gen3_log_info "ignoring service account that does not exist: $saName"
fi

gen3_log_info "devterm" "running $image with labels $labels command ${command[@]}"
gen3_log_info g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --namespace "$namespace" --overrides "$overrides" --labels="$labels" --restart=Never --image=$image --image-pull-policy=$pullPolicy --command -- "${command[@]}"
g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --namespace "$namespace" --overrides "$overrides" --labels="$labels" --restart=Never --image=$image --image-pull-policy=$pullPolicy --env="JENKINS_HOME=devterm" --env="KUBECTL_NAMESPACE=$namespace" --command -- "${command[@]}"
