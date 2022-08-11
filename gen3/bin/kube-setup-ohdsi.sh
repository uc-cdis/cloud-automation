#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

setup_ingress() {
  local hostname=$(gen3 api hostname)
  certs=$(aws acm list-certificates --certificate-statuses ISSUED | jq --arg hostname $hostname -c '.CertificateSummaryList[] | select(.DomainName | contains("*."+$hostname))')
  if [ "$certs" = "" ]; then 
    gen3_log_info "no certs found for *.${hostname}. exiting"
    exit 22
  fi
  gen3_log_info "Found ACM certificate for *.$hostname"
  export ARN=$(jq -r .CertificateArn <<< $certs)
  export ohdsi_hostname="atlas.${hostname}"
  envsubst <${GEN3_HOME}/kube/services/ohdsi/ohdsi-ingress.yaml | g3kubectl apply -f -
}

setup_ingress

gen3 roll ohdsi-webapi
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-service.yaml"

gen3 roll ohdsi-atlas
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-service.yaml"

cat <<EOM
The Atlas/WebAPI service has been deployed onto the k8s cluster.
EOM
