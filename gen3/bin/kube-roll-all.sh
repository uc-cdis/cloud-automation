#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

# Make it easy to run this directly ...
_roll_all_dir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_roll_all_dir}/../.." && pwd)}"

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 kube-setup-workvm
if [[ -f "${WORKSPACE}/${vpc_name}/creds.json" ]]; then # update secrets
  gen3 kube-setup-secrets
fi
gen3 kube-setup-roles
gen3 kube-setup-certs

gen3 roll indexd
g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-service.yaml"

gen3 kube-setup-arborist
gen3 kube-setup-fence
gen3 kube-setup-sheepdog
gen3 kube-setup-peregrine
gen3 kube-setup-arranger
gen3 kube-setup-pidgin
gen3 kube-setup-revproxy
gen3 kube-setup-fluentd
gen3 kube-setup-autoscaler
gen3 kube-setup-kube-dns-autoscaler
gen3 kube-setup-tiller || true
gen3 kube-setup-networkpolicy

# portal is not happy until other services are up
# If new pods are still rolling/starting up, then wait for that to finish
gen3 kube-wait4-pods || true
gen3 roll portal

cat - <<EOM
INFO: 'gen3 roll portal' if necessary to force a restart -
   portal will not come up cleanly until after the reverse proxy
   services is fully up.

EOM
