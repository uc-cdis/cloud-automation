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

# Set flag, so we can avoid doing things over and over
export GEN3_ROLL_ALL=true

gen3 kube-setup-workvm
# kube-setup-roles runs before kube-setup-secrets -
#    setup-secrets may launch a job that needs the useryaml-role
gen3 kube-setup-roles
gen3 kube-setup-secrets
gen3 kube-setup-certs
gen3 jupyter j-namespace setup

gen3_log_info "using manifest at $(g3k_manifest_path)"

# label pods without release version
for name in $(g3kubectl get pods -l 'release!=production,release!=canary' -o jsonpath="{..metadata.name}"); do
  g3kubectl label pods $name release=production || true
done

for name in $(g3kubectl get replicasets -l 'release!=production,release!=canary' -o jsonpath="{..metadata.name}"); do
  g3kubectl label replicasets $name release=production || true
done

# Set up default storage class
if ! g3kubectl get storageclass standard > /dev/null 2>&1; then
  gen3_log_info "Deploying the standard storage class for AWS"
  # gitops sync cronjob may not have permission to do this ...
  g3kubectl apply -f "${GEN3_HOME}/kube/services/storageclass/aws-storageclass.yaml" || true
fi

gen3 kube-setup-networkpolicy disable
#
# Hopefull core secrets/config in place - start bringing up services
#
if g3k_manifest_lookup .versions.indexd 2> /dev/null; then
  gen3 kube-setup-indexd
else
  gen3_log_info "no manifest entry for indexd"
fi

if g3k_manifest_lookup .versions.arborist 2> /dev/null; then
  gen3 kube-setup-arborist || gen3_log_err "arborist setup failed?"
else
  gen3_log_info "no manifest entry for arborist"
fi

if g3k_manifest_lookup .versions.fence 2> /dev/null; then
  # data ecosystem sub-commons may not deploy fence ...
  gen3 kube-setup-fence
elif g3k_manifest_lookup .versions.fenceshib 2> /dev/null; then
  gen3 kube-setup-fenceshib
else
  gen3_log_info "no manifest entry for fence"
fi

if g3k_manifest_lookup .versions.ssjdispatcher 2>&1 /dev/null; then
  gen3 kube-setup-ssjdispatcher
fi

if g3kubectl get cronjob etl >/dev/null 2>&1; then
    gen3 job run etl-cronjob
fi

if g3kubectl get cronjob usersync >/dev/null 2>&1; then
    gen3 job run usersync-cronjob
fi

if g3k_manifest_lookup .versions.sheepdog 2> /dev/null; then
  gen3 kube-setup-sheepdog
else
  gen3_log_info "not deploying sheepdog - no manifest entry for .versions.sheepdog"
fi

if g3k_manifest_lookup .versions.peregrine 2> /dev/null; then
  gen3 kube-setup-peregrine
else
  gen3_log_info "not deploying peregrine - no manifest entry for .versions.peregrine"
fi

if g3k_manifest_lookup .versions.arranger 2> /dev/null; then
  gen3 kube-setup-arranger
else
  gen3_log_info "not deploying arranger - no manifest entry for .versions.arranger"
fi

if g3k_manifest_lookup .versions.spark 2> /dev/null; then
  #
  # Only if not already deployed - otherwise it may interrupt a running ETL
  #
  if ! g3kubectl get deployment spark-deployment > /dev/null 2>&1; then
    gen3 kube-setup-spark
  fi
else
  gen3_log_info "not deploying spark (required for ES ETL) - no manifest entry for .versions.spark"
fi

if g3k_manifest_lookup .versions.guppy 2> /dev/null; then
  gen3 kube-setup-guppy
else
  gen3_log_info "not deploying guppy - no manifest entry for .versions.guppy"
fi

if g3k_manifest_lookup .versions.pidgin 2> /dev/null; then
  gen3 kube-setup-pidgin
else
  gen3_log_info "not deploying pidgin - no manifest entry for .versions.pidgin"
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
  gen3_log_info "not deploying manifestservice - no manifest entry for .versions.manifestservice"
fi

if g3k_manifest_lookup .versions.ambassador 2> /dev/null; then
  gen3 kube-setup-ambassador
else
  gen3_log_info "not deploying ambassador - no manifest entry for .versions.ambassador"
fi

if g3k_manifest_lookup .versions.dashboard > /dev/null 2>&1; then
  gen3 kube-setup-dashboard
else
  gen3_log_info "not deploying dashboard - no manifest entry for .versions.dashboard"
fi

if g3k_manifest_lookup .versions.hatchery 2> /dev/null; then
  gen3 kube-setup-hatchery
else
  gen3_log_info "not deploying hatchery - no manifest entry for .versions.hatchery"
fi

if g3k_manifest_lookup .versions.hatchery 2> /dev/null && g3kubectl get statefulset jupyterhub-deployment > /dev/null 2>&1; then
  gen3_log_info "deleting jupyterhub-deployment because Hatchery is deployed"
  g3kubectl delete statefulset jupyterhub-deployment || true
fi

if g3k_manifest_lookup .versions.hatchery 2> /dev/null && g3kubectl get service jupyterhub-service > /dev/null 2>&1; then
  gen3_log_info "deleting jupyterhub-service because Hatchery is deployed"
  g3kubectl delete service jupyterhub-service || true
fi

if g3k_manifest_lookup .versions.sower 2> /dev/null; then
  gen3 kube-setup-sower
else
  gen3_log_info "not deploying sower - no manifest entry for .versions.sower"
fi

gen3 kube-setup-revproxy

# Internal k8s systems
gen3 kube-setup-fluentd
gen3 kube-setup-autoscaler
gen3 kube-setup-kube-dns-autoscaler
gen3 kube-setup-metrics deploy || true
gen3 kube-setup-tiller || true
#
gen3 kube-setup-networkpolicy disable
gen3 kube-setup-networkpolicy

#
# portal and wts are not happy until other services are up
# If new pods are still rolling/starting up, then wait for that to finish
#
gen3 kube-wait4-pods || true

if g3k_manifest_lookup .versions.wts 2> /dev/null; then
  # this tries to kubectl exec into fence
  gen3 kube-setup-wts || true
else
  gen3_log_info "not deploying wts - no manifest entry for .versions.wts"
fi

if g3k_manifest_lookup .versions.portal 2> /dev/null; then
  gen3 kube-setup-portal
else
  gen3_log_info "not deploying portal - no manifest entry for .versions.portal"
fi

gen3_log_info "enable network policy"
gen3 kube-setup-networkpolicy "enable" || true
gen3_log_info "apply pod scaling"
gen3 scaling apply all || true
gen3_log_info "roll-all" "roll completed successfully!"

# this requires AWS permissions ...
#gen3 dashboard gitops-sync || true
