#!/bin/bash
#

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! g3kubectl get storageclass gp2 > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/mssql-restore-job/10storageclass.yaml"
fi
if ! g3kubectl get persistentvolumeclaim datadir-mssql-dump > /dev/null 2>&1; then
  g3kubectl apply -f "${GEN3_HOME}/kube/services/jobs/mssql-restore-job/00pvc.yaml"
fi
