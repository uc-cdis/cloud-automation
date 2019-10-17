#!/bin/bash
#
# Deploy data-ingestion-job into existing commons
# This job is specific to DataSTAGE
# Usage: gen3 kube-setup-data-ingestion-job <phs_id_list_filepath> <data_requiring_manual_review_filepath>

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

PHS_ID_LIST_PATH=devplanetv1/apis_configs/data-ingestion-job-phs-id-list.txt
if [ $# -ge 1 ]
  then PHS_ID_LIST_PATH=$1
fi

DATA_REQUIRING_MANUAL_REVIEW_PATH=devplanetv1/apis_configs/data_requiring_manual_review.tsv
if [ $# -ge 2 ]
  then DATA_REQUIRING_MANUAL_REVIEW_PATH=$1
fi

g3kubectl delete configmap phs-id-list
g3kubectl delete configmap data-requiring-manual-review

g3kubectl create configmap phs-id-list --from-file=$PHS_ID_LIST_PATH
if [ -f "$DATA_REQUIRING_MANUAL_REVIEW_PATH" ]; then
  g3kubectl create configmap data-requiring-manual-review --from-file=$DATA_REQUIRING_MANUAL_REVIEW_PATH
fi

gen3 runjob data-ingestion-job