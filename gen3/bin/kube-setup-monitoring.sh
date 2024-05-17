#!/bin/bash
#
#  Prometheus would let us gather some useful metrics from the cluster that should help us out troubleshooting and improving
#

# Load the basics

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

# Deploy Prometheus with argocd if flag is set in the manifest path
manifestPath=$(g3k_manifest_path)
argocd="$(jq -r ".[\"global\"][\"argocd\"]" < "$manifestPath" | tr '[:upper:]' '[:lower:]')"

if [[ -n "$JENKINS_HOME" ]]; then
  gen3_log_info "Jenkins skipping prometheus/grafana setup: $JENKINS_HOME"
  exit 0
fi

function helm_repository()
{
  if ! helm repo list | grep grafana > /dev/null 2>&1; then
    gen3_log_info "Adding grafana helm repo.."
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
  fi
}

function delete_prometheus()
{
  gen3 arun helm delete prometheus --namespace prometheus
}

# function delete_grafana()
# {
#   gen3 arun helm delete grafana --namespace grafana
# }

# function create_grafana_secrets()
# {
#   if ! g3kubectl get secrets/grafana-admin > /dev/null 2>&1; then
#     credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
#     creds="$(base64 /dev/urandom | head -c 12)"
#     if [[ "$creds" != null ]]; then
#       echo ${creds} >> "$credsFile"
#       g3kubectl create secret generic grafana-admin "--from-file=credentials=${credsFile}"
#       rm -f ${credsFile}
#     else
#       echo "WARNING: there was an error creating the secrets for grafana"
#     fi
#   fi
# }

function cleanup_old_monitoring() {
  gen3_log_info "cleaning up old monitoring set up"
  if [ "$argocd" == "true" ]; then
    if (kubectl get app -n argocd prometheus-application > /dev/null 2>&1); then
      gen3_log_info "Deleting old prometheus set up"
      g3kubectl delete app prometheus-application -n argocd &
      # Have argocd not to wait for the app to be deleted
      g3kubectl patch app prometheus-application  -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge -n argocd || true
    fi
  else 
    # Check if the 'prometheus' release exists in the 'monitoring' namespace
    if helm list -n monitoring -q | grep -qw "prometheus"; then
        echo "Helm release 'prometheus' found in 'monitoring' namespace. Deleting..."
        # Attempt to delete the 'prometheus' release
        helm uninstall prometheus -n monitoring
        if [ $? -eq 0 ]; then
            echo "Helm release 'prometheus' successfully deleted."
        else
            echo "Failed to delete Helm release 'prometheus'."
        fi
    else
        echo "No 'prometheus' release found in 'monitoring' namespace."
    fi
  fi

  # Delete thanos resources
  g3kubectl delete -f "${GEN3_HOME}/kube/services/monitoring/thanos-deploy.yaml" > /dev/null 2>&1 || true
  g3kubectl delete secret -n monitoring thanos-objstore-config > /dev/null 2>&1  || true

  gen3_log_info "Old resources have been cleaned up"
}

function setup_s3_backend () {
  if  [[ -z $vpc_name ]]; then
    local vpc_name="$(gen3 api environment)"
  fi
  roleName="$vpc_name-observability-role"
  saName="observability"
  bucketName="$vpc_name-observability-bucket"
  gen3 s3 create "$bucketName"
  gen3 awsrole create "$roleName" "$saName" "monitoring" || return 1
  gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name ${roleName} || true
}

function deploy_lgtma() {
  gen3_log_info "Deploying LGTM stack from grafana for monitoring/observability"
  if [ "$argocd" == "true" ]; then
    gen3_log_info "ArgoCD has been enabled, will deploy the LGTMA stack as argocd app"
    g3kubectl apply -f "${GEN3_HOME}/kube/services/monitoring/lgtma-app.yaml"
    environment="$(gen3 api environment)"
    gen3_log_info "Deploying monitoring for $environment"
    g3k_kv_filter ${GEN3_HOME}/kube/services/monitoring/lgtma-app.yaml CURRENT_ENV "$environment"|g3kubectl apply -f -
    g3kubectl apply -f "${GEN3_HOME}/kube/services/monitoring/alloy-config.yaml"
  else
    gen3_log_info "ArgoCD not enabled, skipping setup."
    exit 0
  fi
}



function deploy_monitoring()
{
  #
  # Avoid doing this more than once
  # We may have multiple commons running on the same k8s cluster,
  # but we only have one prometheus.
  #
  helm_repository
  cleanup_old_monitoring

  # setup s3, iam and IRSA for observability
  setup_s3_backend

  # Deploy loki (logs), grafana (frontend), tempo (tracing), mimir (metrics) and alloy (agent)
  deploy_lgtma

  # kube-setup-revproxy
  if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-revproxy
fi

}



command=""
if [[ $# -gt 0 && ! "$1" =~ ^-*force ]]; then
  command="$1"
  shift
fi
case "$command" in
  *)
    deploy_monitoring "$@"
    ;;
esac
