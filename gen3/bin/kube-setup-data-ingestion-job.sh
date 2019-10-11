#!/bin/bash
#
# Deploy data-ingestion-job into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to DataSTAGE

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

PHS_ID_LIST_PATH=devplanetv1/apis_configs/data-ingestion-job-phs-id-list.txt
if [ $# -eq 1 ]
  then PHS_ID_LIST_PATH=$1
fi

g3kubectl create configmap phs-id-list --from-file=$PHS_ID_LIST_PATH

gen3 runjob data-ingestion-job