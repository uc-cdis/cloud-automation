#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

secret_folder="$(gen3_secrets_folder)"

if [[ -d ${secret_folder}/apis_configs/dcf_dataservice ]]; then
  if g3kubectl get secret dcf-aws-creds-secret; then
    g3kubectl delete secret dcf-aws-creds-secret
  fi
  if g3kubectl get secret dcf-aws-fence-creds-secret; then
    g3kubectl delete secret dcf-aws-fence-creds-secret
  fi
  if g3kubectl get secret google-creds-secret; then
    g3kubectl delete secret google-creds-secret
  fi
  if g3kubectl get secret dcf-dataservice-json-secret; then
    g3kubectl delete secret dcf-dataservice-json-secret
  fi
  if g3kubectl get secret dcf-dataservice-settings-secrets; then
    g3kubectl delete secret dcf-dataservice-settings-secrets
  fi
  if g3kubectl get configmap project-map-manifest; then
    g3kubectl delete configmap project-map-manifest
  fi
 
  if ! hostname="$(gen3 api hostname)"; then
    gen3_log_err "could not determine hostname from manifest-global - bailing out of data refresh setup"
    return 1
  fi

  cp ${GEN3_MANIFEST_HOME}/${hostname}/manifests/datarefresh/GDC_project_map.json ${secret_folder}/apis_configs/dcf_dataservice/GDC_project_map.json

  GDC_TOKEN=$(cat ${secret_folder}/apis_configs/dcf_dataservice/creds.json | jq '.GDC_TOKEN')
  INDEXD_CRED=$(cat ${secret_folder}/apis_configs/dcf_dataservice/creds.json | jq '.INDEXD')

  cat >${secret_folder}/apis_configs/dcf_dataservice/dcf_dataservice_settings << EOL
GDC_TOKEN = ${GDC_TOKEN}
  
INDEXD = ${INDEXD_CRED}

DATA_ENDPT = "https://api.gdc.cancer.gov/data/"

PROJECT_ACL = $(cat ${secret_folder}/apis_configs/dcf_dataservice/GDC_project_map.json)

IGNORED_FILES = "/dcf-dataservice/ignored_files_manifest.csv"
EOL

  g3kubectl create secret generic dcf-aws-creds-secret --from-file=credentials=${secret_folder}/apis_configs/dcf_dataservice/aws_creds_secret
  g3kubectl create secret generic dcf-aws-fence-creds-secret --from-file=credentials=${secret_folder}/apis_configs/dcf_dataservice/aws_fence_bot_secret
  g3kubectl create secret generic google-creds-secret --from-file=google_service_account_creds=${secret_folder}/apis_configs/dcf_dataservice/gcloud-creds-secret
  g3kubectl create secret generic dcf-dataservice-json-secret --from-file=dcf_dataservice_credentials.json=${secret_folder}/apis_configs/dcf_dataservice/creds.json
  g3kubectl create secret generic dcf-dataservice-settings-secrets --from-file=dcf_dataservice_settings=${secret_folder}/apis_configs/dcf_dataservice/dcf_dataservice_settings
  g3kubectl create configmap project-map-manifest --from-file=GDC_project_map.json=${secret_folder}/apis_configs/dcf_dataservice/GDC_project_map.json
fi