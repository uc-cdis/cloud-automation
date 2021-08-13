#!/bin/bash
#
# This script will create a new gen3 environment from scratch
# to be used in ephemeral CI runs

# TODO: leverage gen3 config-env to *copy* config from existing envs and
# create ephemeral CI environments of any flavours we want (e.g., anvil, va, covid10, heal, etc.)

source ${GEN3_HOME}/gen3/lib/utils.sh
gen3_load "gen3/gen3setup"

# the code below should be atrocious as the fix-it-friday experiment is based on DTSTTCPW

# TODO: come up with better env counter mechanism
# pick up current ci-env counter
ciEnvNumber=$(cat ci-envs-counter.txt)

# TODO increment counter later, let us make this work for now
# TODO: consider a limit of ci envs (save some moola)
# TODO: come up with cronjob to tear down old environments
# Reminder, use the following commands to tear down envs.:
# sudo rm -Rf /home/jenkins-ci-3/ && sudo sed -i '/jenkins-ci-3/d' /etc/passwd && sudo sed -i '/jenkins-ci-3/d' /etc/group && kubectl delete namespace jenkins-ci-3
namespace "jenkins-ci-3" deleted

set -x

# step 1 - Create new workspace by cloning qaplanetv1
workspaceAlreadyExist=$(g3kubectl get ns | awk '{ print $1 }' | grep -v NAME | grep jenkins-ci-$ciEnvNumber)
if [ -z "$workspaceAlreadyExist" ]; then
  gen3 kube-dev-namespace jenkins-ci-$ciEnvNumber
else
  echo "this ci env workspace alredy exists..."
fi

# step 2 -
