#!/bin/bash
#
# Initializes the Gen3 k8s cronjobs.
#

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


if ! g3kubectl get cronjob google-manage-keys > /dev/null 2>&1; then
   g3kubectl create -f "${GEN3_HOME}/kube/services/jobs/google-manage-keys-cronjob.yaml"
fi

if ! g3kubectl get cronjob google-manage-account-access > /dev/null 2>&1; then
   g3kubectl create -f "${GEN3_HOME}/kube/services/jobs/google-manage-account-access-cronjob.yaml"
fi

if ! g3kubectl get cronjob google-init-proxy-groups > /dev/null 2>&1; then
   g3kubectl create -f "${GEN3_HOME}/kube/services/jobs/google-init-proxy-groups-cronjob.yaml"
fi

if ! g3kubectl get cronjob google-delete-expired-service-account > /dev/null 2>&1; then
   g3kubectl create -f "${GEN3_HOME}/kube/services/jobs/google-delete-expired-service-account-cronjob.yaml"
fi


if ! g3kubectl get cronjob google-verify-bucket-access-group > /dev/null 2>&1; then
   g3kubectl create -f "${GEN3_HOME}/kube/services/jobs/google-verify-bucket-access-group-cronjob.yaml"
fi
