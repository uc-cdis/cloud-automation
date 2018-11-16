#!/bin/bash
#
# Initializes the Gen3 k8s cronjobs.
#

set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


gen3 job run "${GEN3_HOME}/kube/services/jobs/google-manage-keys-cronjob.yaml"

gen3 job run "${GEN3_HOME}/kube/services/jobs/google-manage-account-access-cronjob.yaml"

gen3 job run "${GEN3_HOME}/kube/services/jobs/google-init-proxy-groups-cronjob.yaml"

gen3 job run "${GEN3_HOME}/kube/services/jobs/google-delete-expired-service-account-cronjob.yaml"

gen3 job run "${GEN3_HOME}/kube/services/jobs/google-verify-bucket-access-group-cronjob.yaml"

gen3 roll google-sa-validation
g3kubectl apply -f "${GEN3_HOME}/kube/services/google-sa-validation/google-sa-validation-service.yaml"
