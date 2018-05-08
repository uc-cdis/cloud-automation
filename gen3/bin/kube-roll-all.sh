#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
# Note that kube.tf cat's this file into ${vpc_name}_output/kube-services.sh,
# but can also run this standalone if the environment is
# properly configured.
#
set -e

_KUBE_SERVICES_BODY=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SERVICES_BODY}/../lib/kube-setup-init.sh"

gen3 kube-setup-workvm
if [[ -f "${WORKSPACE}/${vpc_name}_output/creds.json" ]]; then # update secrets
  gen3 kube-setup-secrets
fi
gen3 kube-setup-roles
gen3 kube-setup-certs
if [[ -f "${WORKSPACE}/${vpc_name}/credentials/ca.pem" ]]; then
  gen3 kube-setup-certs
else
  echo "INFO: certificate authority not available - skipping SSL cert check"
fi

gen3 roll indexd
g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-service.yaml"

gen3 kube-setup-fence
gen3 kube-setup-sheepdog
gen3 kube-setup-peregrine
gen3 kube-setup-revproxy
gen3 kube-setup-fluentd
gen3 kube-setup-networkpolicy

# portal is not happy until other services are up
gen3 roll portal

cat - <<EOM
INFO: delete the portal pod if necessary to force a restart -
   portal will not come up cleanly until after the reverse proxy
   services is fully up.

EOM
