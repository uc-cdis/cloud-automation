#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -d ${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice ]]; then
  g3kubectl delete secret dcf-aws-creds-secret
  g3kubectl delete secret google-creds-secret
  g3kubectl delete secret dcf-dataservice-json-secret
  g3kubectl delete secret dcf-dataservice-settings-secrets
  g3kubectl delete configmap project-map-manifest

  g3kubectl create secret generic dcf-aws-creds-secret --from-file=credentials=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/aws_creds_secret
  g3kubectl create secret generic google-creds-secret --from-file=google_service_account_creds=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/gcloud-creds-secret
  g3kubectl create secret generic dcf-dataservice-json-secret --from-file=dcf_dataservice_credentials.json=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/creds.json
  g3kubectl create secret generic dcf-dataservice-settings-secrets --from-file=dcf_dataservice_settings=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/dcf_dataservice_settings
  g3kubectl create configmap project-map-manifest --from-file=GDC_project_map.json=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/GDC_project_map.json
fi