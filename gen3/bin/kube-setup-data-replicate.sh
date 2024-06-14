#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

secret_folder="$(gen3_secrets_folder)"

if [[ -d ${secret_folder}/apis_configs/dcf_dataservice ]]; then
  if g3kubectl get secret aws-creds-secret; then
    g3kubectl delete secret aws-creds-secret
  fi
  if g3kubectl get secret google-creds-secret; then
    g3kubectl delete secret google-creds-secret
  fi
  if g3kubectl get secret dataservice-settings-secrets; then
    g3kubectl delete secret dataservice-settings-secrets
  fi
  if g3kubectl get secret dcf-dataservice-settings-secrets; then
    g3kubectl delete secret dcf-dataservice-settings-secrets
  fi
 
  if ! hostname="$(gen3 api hostname)"; then
    gen3_log_err "could not determine hostname from manifest-global - bailing out of data refresh setup"
    return 1
  fi

  cat >${secret_folder}/apis_configs/dcf_dataservice/dcf_dataservice_settings.json << EOL

EOL

  g3kubectl create secret generic aws-creds-secret --from-file=credentials=${secret_folder}/apis_configs/dcf_dataservice/aws_creds_secret
  g3kubectl create secret generic google-creds-secret --from-file=google_service_account_creds=${secret_folder}/apis_configs/dcf_dataservice/gcloud-creds-secret
  g3kubectl create secret generic dataservice-settings-secrets --from-file=dataservice_settings.json=${secret_folder}/apis_configs/dcf_dataservice/dataservice_settings.json
  g3kubectl create secret generic dcf-dataservice-settings-secrets --from-file=dcf_dataservice_settings.json=${secret_folder}/apis_configs/dcf_dataservice/dcf_dataservice_settings.json

fi
