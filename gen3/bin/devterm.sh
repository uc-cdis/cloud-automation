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

if [[ -z "$1" ]]; then
  g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --labels="app=gen3job,name=devterm" --restart=Never --image=quay.io/cdis/awshelper:master --image-pull-policy=Always --command -- /bin/bash
else
  commandStr="$1"
  g3kubectl run "awshelper-devterm-$(date +%s)" -it --rm=true --labels="app=gen3job,name=devterm" --restart=Never --image=quay.io/cdis/awshelper:master --image-pull-policy=Always --command -- /bin/bash -c "$commandStr"
fi
