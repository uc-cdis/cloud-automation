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
# kube-setup-roles runs before kube-setup-secrets -
#    setup-secrets may launch a job that needs the useryaml-role
gen3 kube-setup-roles
gen3 kube-setup-secrets
gen3 kube-setup-certs
gen3 jupyter j-namespace setup

echo "INFO: using manifest at $(g3k_manifest_path)"

# label pods without release version
for name in $(g3kubectl get pods -l 'release!=production,release!=canary' -o jsonpath="{..metadata.name}"); do
  g3kubectl label pods $name release=production || true
done

for name in $(g3kubectl get replicasets -l 'release!=production,release!=canary' -o jsonpath="{..metadata.name}"); do
  g3kubectl label replicasets $name release=production || true
done

gen3 kube-setup-indexd
gen3 kube-setup-arborist || true
gen3 kube-setup-fence

gen3 kube-setup-ssjdispatcher

if g3kubectl get cronjob usersync >/dev/null 2>&1; then
    gen3 job run "${GEN3_HOME}/kube/services/jobs/usersync-cronjob.yaml"
fi

if g3kubectl get configmap manifest-google >/dev/null 2>&1; then
  gen3 kube-setup-google
fi

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

if g3k_manifest_lookup .versions.arranger 2> /dev/null; then
  gen3 kube-setup-arranger
else
  echo "INFO: not deploying arranger - no manifest entry for .versions.arranger"
fi

#
# Do not do this - it may interrupt a running ETL
#
#if g3k_manifest_lookup .versions.spark 2> /dev/null; then
#  gen3 kube-setup-spark
#else
#  echo "INFO: not deploying spark (required for ES ETL) - no manifest entry for .versions.spark"
#fi

if g3k_manifest_lookup .versions.guppy 2> /dev/null; then
  gen3 kube-setup-guppy
else
  echo "INFO: not deploying guppy - no manifest entry for .versions.guppy"
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

if g3k_manifest_lookup .versions.wts 2> /dev/null; then
  # go ahead and deploy the service, so the revproxy setup sees it
  g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/wts-service.yaml"
  # wait till after fence is up to do a full setup - see below
fi

if g3k_manifest_lookup .versions.manifestservice 2> /dev/null; then
  gen3 kube-setup-manifestservice
else
  echo "INFO: not deploying manifestservice - no manifest entry for .versions.manifestservice"
fi

gen3 kube-setup-revproxy

# Internal k8s systems
gen3 kube-setup-fluentd
gen3 kube-setup-autoscaler
gen3 kube-setup-kube-dns-autoscaler
gen3 kube-setup-tiller || true
#
# Disable this stuff for now - ugh!
#gen3 kube-setup-networkpolicy disable
#gen3 kube-setup-networkpolicy noservice
g3kubectl delete networkpolicies --all

#
# portal and wts are not happy until other services are up
# If new pods are still rolling/starting up, then wait for that to finish
#
gen3 kube-wait4-pods || true

if g3k_manifest_lookup .versions.wts 2> /dev/null; then
  # this tries to kubectl exec into fence 
  gen3 kube-setup-wts || true
else
  echo "INFO: not deploying wts - no manifest entry for .versions.wts"
fi

if g3k_manifest_lookup .versions.portal 2> /dev/null; then
  gen3 kube-setup-portal
else
  echo "INFO: not deploying portal - no manifest entry for .versions.portal"
fi

if g3kubectl get statefulset jupyterhub-deployment > /dev/null 2>&1 && [[ "$(g3kubectl get statefulsets jupyterhub-deployment -o json | jq -r '.metadata.labels.public')" != "yes" ]]; then 
  gen3_log_info "roll-all" "rolling jupyterhub - need to update labels for network policy"
  g3kubectl delete statefulset jupyterhub-deployment || true
  gen3 roll jupyterhub
fi

gen3_log_info "roll-all" "roll completed successfully!"
#gen3 kube-setup-networkpolicy enable
