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
gen3 kube-setup-secrets
gen3 kube-setup-roles
gen3 kube-setup-certs

echo "INFO: using manifest at $(g3k_manifest_path)"
gen3 roll indexd
g3kubectl apply -f "${GEN3_HOME}/kube/services/indexd/indexd-service.yaml"

gen3 kube-setup-arborist
gen3 kube-setup-fence

if g3k_manifest_lookup .versions.sheepdog 2> /dev/null; then
  gen3 kube-setup-sheepdog
else
  echo "INFO: not deploying sheepdog - no manifest entry for .versions.sheepdog"
fi

if g3k_manifest_lookup .versions.peregrine 2> /dev/null; then
  gen3 kube-setup-peregrine
else
  echo "INFO: not deploying peregrine - no manifest entry for .versions.peregrine"
fi
kubectl wait --for=condition=complete job/update-dict

if g3k_manifest_lookup .versions.arranger 2> /dev/null; then
  gen3 kube-setup-arranger
else
  echo "INFO: not deploying arranger - no manifest entry for .versions.arranger"
fi

if g3k_manifest_lookup .versions.pidgin 2> /dev/null; then
  gen3 kube-setup-pidgin
else
  echo "INFO: not deploying pidgin - no manifest entry for .versions.pidgin"
fi

if g3k_manifest_lookup .versions.portal > /dev/null 2>&1; then
  #
  # deploy the portal-service, so kube-setup-revproxy knows
  # that we need to proxy the portal ...
  # Wait to deploy the portal, because portal wants to connect
  # to the reverse proxy ...
  #
  g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml"
fi

gen3 kube-setup-revproxy

# Internal k8s systems
gen3 kube-setup-fluentd
gen3 kube-setup-autoscaler
gen3 kube-setup-kube-dns-autoscaler
gen3 kube-setup-tiller || true
gen3 kube-setup-networkpolicy

if g3k_manifest_lookup .versions.portal 2> /dev/null; then
  # portal is not happy until other services are up
  # If new pods are still rolling/starting up, then wait for that to finish
  gen3 kube-wait4-pods || true
  g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml"
  gen3 roll portal
else
  echo "INFO: not deploying portal - no manifest entry for .versions.portal"
fi

cat - <<EOM
INFO: 'gen3 roll portal' if necessary to force a restart -
   portal will not come up cleanly until after the reverse proxy
   services is fully up.

EOM
