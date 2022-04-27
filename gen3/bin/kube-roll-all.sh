#!/bin/bash
#
# Initializes the Gen3 k8s secrets and services.
#
set -e

# Make it easy to run this directly ...
_roll_all_dir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(cd "${_roll_all_dir}/../.." && pwd)}"

if [[ "$1" =~ ^-*fast$ ]]; then
  GEN3_ROLL_FAST=true
  shift
fi

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# Set flag, so we can avoid doing things over and over
export GEN3_ROLL_ALL=true

if [[ "$GEN3_ROLL_FAST" != "true" ]]; then
  gen3 kube-setup-workvm
  # kube-setup-roles runs before kube-setup-secrets -
  #    setup-secrets may launch a job that needs the useryaml-role
  gen3 kube-setup-roles &
  gen3 kube-setup-secrets &
  gen3 kube-setup-certs &
  gen3 jupyter j-namespace setup &
else
  gen3_log_info "roll fast mode - skipping secrets setup"
fi

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
  gen3 kube-setup-indexd &
else
  gen3_log_info "no manifest entry for indexd"
fi

if g3k_manifest_lookup .versions.arborist 2> /dev/null; then
  gen3 kube-setup-arborist || gen3_log_err "arborist setup failed?"
else
  gen3_log_info "no manifest entry for arborist"
fi

if g3k_manifest_lookup '.versions["audit-service"]' 2> /dev/null; then
  gen3 kube-setup-audit-service
else
  gen3_log_info "not deploying audit-service - no manifest entry for .versions.audit-service"
fi

if g3k_manifest_lookup .versions.auspice 2> /dev/null; then
  gen3 kube-setup-auspice
else
  gen3_log_info "not deploying auspice - no manifest entry for .versions.auspice"
fi

if g3k_manifest_lookup .versions.fence 2> /dev/null; then
  # data ecosystem sub-commons may not deploy fence ...
  gen3 kube-setup-fence &
elif g3k_manifest_lookup .versions.fenceshib 2> /dev/null; then
  gen3 kube-setup-fenceshib &
else
  gen3_log_info "no manifest entry for fence"
fi

# Set a var for the cron folder path
g3k_cron_manifest_folder="$(g3k_manifest_path | rev | cut -d '/' -f2- | rev)/manifests/cronjobs"
# Check for file with defined cronjobs
if [[ -f "$g3k_cron_manifest_folder/cronjobs.json" ]]; then
  keys=$(g3k_config_lookup 'keys[]' $g3k_cron_manifest_folder/cronjobs.json)
fi
# Setup a cronjob with the specified schedule for each key/value in the cronjob manifest
for key in $keys; do
  gen3_log_info "Setting up specified $key cronjob"
  gen3 job cron $key "$(g3k_config_lookup .\"$key\" $g3k_cron_manifest_folder/cronjobs.json)"
done
# Setup ETL cronjob normally if it is already there and not defined in manifest
if [[ ! "${keys[@]}" =~ "etl" ]] && g3kubectl get cronjob etl >/dev/null 2>&1; then
    gen3 job run etl-cronjob
fi
# Setup usersync cronjob normally if it is already there and not defined in manifest
if [[ ! "${keys[@]}" =~ "usersync" ]] && g3kubectl get cronjob usersync >/dev/null 2>&1; then
    # stagger usersync jobs, so they don't all hit
    # NIH at the same time
    ustart=$((20 + (RANDOM % 20)))
    gen3 job cron usersync "$ustart * * * *"
fi

if g3k_manifest_lookup .versions.sheepdog 2> /dev/null; then
  gen3 kube-setup-sheepdog &
else
  gen3_log_info "not deploying sheepdog - no manifest entry for .versions.sheepdog"
fi

if g3k_manifest_lookup .versions.peregrine 2> /dev/null; then
  gen3 kube-setup-peregrine &
else
  gen3_log_info "not deploying peregrine - no manifest entry for .versions.peregrine"
fi

if g3k_manifest_lookup .versions.arranger 2> /dev/null; then
  gen3 kube-setup-arranger &
else
  gen3_log_info "not deploying arranger - no manifest entry for .versions.arranger"
fi

if g3k_manifest_lookup .versions.spark 2> /dev/null; then
  #
  # Only if not already deployed - otherwise it may interrupt a running ETL
  #
  if ! g3kubectl get deployment spark-deployment > /dev/null 2>&1; then
    gen3 kube-setup-spark &
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
  gen3 kube-setup-pidgin &
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
  g3kubectl apply -f "${GEN3_HOME}/kube/services/portal/portal-service.yaml" &
fi

if g3k_manifest_lookup .versions.wts 2> /dev/null; then
  # go ahead and deploy the service, so the revproxy setup sees it
  g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/wts-service.yaml" &
  # wait till after fence is up to do a full setup - see below
fi

if g3k_manifest_lookup .versions.manifestservice 2> /dev/null; then
  gen3 kube-setup-manifestservice &
else
  gen3_log_info "not deploying manifestservice - no manifest entry for .versions.manifestservice"
fi

if g3k_manifest_lookup .versions.ambassador 2> /dev/null; then
  gen3 kube-setup-ambassador &
else
  gen3_log_info "not deploying ambassador - no manifest entry for .versions.ambassador"
fi

if g3k_manifest_lookup .versions.dashboard > /dev/null 2>&1; then
  gen3 kube-setup-dashboard
  gen3 dashboard gitops-sync || true
else
  gen3_log_info "not deploying dashboard - no manifest entry for .versions.dashboard"
fi

if g3k_manifest_lookup .versions.hatchery 2> /dev/null; then
  gen3 kube-setup-hatchery &
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
  gen3 kube-setup-sower &
else
  gen3_log_info "not deploying sower - no manifest entry for .versions.sower"
fi

if g3k_manifest_lookup .versions.requestor 2> /dev/null; then
  gen3 kube-setup-requestor &
else
  gen3_log_info "not deploying requestor - no manifest entry for .versions.requestor"
fi

gen3 kube-setup-metadata

if g3k_manifest_lookup .versions.ssjdispatcher 2>&1 /dev/null; then
  gen3 kube-setup-ssjdispatcher &
fi

if g3k_manifest_lookup '.versions["access-backend"]' 2> /dev/null; then
  gen3 kube-setup-access-backend &
else
  gen3_log_info "not deploying access-backend - no manifest entry for .versions.access-backend"
fi

if g3k_manifest_lookup '.versions["audit-service"]' 2> /dev/null; then
  gen3 kube-setup-audit-service &
else
  gen3_log_info "not deploying audit-service - no manifest entry for .versions.audit-service"
fi

if g3k_manifest_lookup '.versions["dicom-server"]' 2> /dev/null; then
  gen3 kube-setup-dicom-server &
else
  gen3_log_info "not deploying dicom-server - no manifest entry for '.versions[\"dicom-server\"]'"
fi

if g3k_manifest_lookup '.versions["dicom-viewer"]' 2> /dev/null; then
  gen3 kube-setup-dicom-viewer &
else
  gen3_log_info "not deploying dicom-viewer - no manifest entry for '.versions[\"dicom-viewer\"]'"
fi

gen3 kube-setup-revproxy

if [[ "$GEN3_ROLL_FAST" != "true" ]]; then
  # Internal k8s systems
  gen3 kube-setup-fluentd &
  gen3 kube-setup-autoscaler &
  gen3 kube-setup-kube-dns-autoscaler &
  gen3 kube-setup-metrics deploy || true
  gen3 kube-setup-tiller || true
  #
  gen3 kube-setup-networkpolicy disable &
  gen3 kube-setup-networkpolicy &
else
  gen3_log_info "roll fast mode - skipping k8s base services and netpolicy setup"
fi

#
# portal and wts are not happy until other services are up
# If new pods are still rolling/starting up, then wait for that to finish
#
gen3 kube-wait4-pods || true

if g3k_manifest_lookup .versions.wts 2> /dev/null; then
  # this tries to kubectl exec into fence
  gen3 kube-setup-wts &
else
  gen3_log_info "not deploying wts - no manifest entry for .versions.wts"
fi

if g3k_manifest_lookup .versions.mariner 2> /dev/null; then
  gen3 kube-setup-mariner &
else
  gen3_log_info "not deploying mariner - no manifest entry for .versions.mariner"
fi

if g3k_manifest_lookup '.versions["ws-storage"]' 2> /dev/null; then
  gen3 kube-setup-ws-storage &
else
  gen3_log_info "not deploying ws-storage - no manifest entry for '.versions[\"ws-storage\"]'"
fi

if g3k_manifest_lookup '.sower[] | select( .name=="batch-export" )' 2> /dev/null; then
  gen3 kube-setup-batch-export &
else
  gen3_log_info "not deploying batch-export - no manifest entry for '.versions[\"batch-export\"]'"
fi

if g3k_manifest_lookup .versions.portal 2> /dev/null; then
  gen3 kube-setup-portal &
else
  gen3_log_info "not deploying portal - no manifest entry for .versions.portal"
fi

if g3k_manifest_lookup '.versions["frontend-framework"]' 2> /dev/null; then
  gen3 kube-setup-frontend-framework &
else
  gen3_log_info "not deploying frontend-framework - no manifest entry for '.versions[\"frontend-framework\"]'"
fi

gen3_log_info "enable network policy"
gen3 kube-setup-networkpolicy "enable" || true &

if [[ "$GEN3_ROLL_FAST" != "true" ]]; then
  gen3_log_info "apply pod scaling"
  gen3 scaling apply all || true &
else
  gen3_log_info "roll fast mode - skipping scaling config"
fi

# Wait for all the background commands to finish (any command with an &)
wait
if gen3 kube-wait4-pods; then
  gen3_log_info "roll-all" "roll completed successfully!"
else
  gen3_log_err "looks like not everything is healthy"
  exit 1
fi

# this requires AWS permissions ...
#gen3 dashboard gitops-sync || true
