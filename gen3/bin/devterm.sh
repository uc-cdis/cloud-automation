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
  echo "devterm mounting jenkins service account" 1>&2
  overrides='{ "spec": { "serviceAccountName": "jenkins-service" }}'
fi

if [[ $# -lt 1 ]]; then
  g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --overrides "$overrides" --generator=run-pod/v1 --labels="app=gen3job,name=devterm,netnolimit=yes" --restart=Never --image=quay.io/cdis/awshelper:master --image-pull-policy=Always --command -- /bin/bash
else
  g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --overrides "$overrides"  --generator=run-pod/v1 --labels="app=gen3job,name=devterm,netnolimit=yes" --restart=Never --image=quay.io/cdis/awshelper:master --image-pull-policy=Always --command -- /bin/bash -c "$*"
fi
