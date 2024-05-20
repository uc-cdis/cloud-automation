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
  if ! helm repo list > /dev/null 2>&1; then
    # helm3 has no default repo, need to add it manually
    #helm repo add stable https://charts.helm.sh/stable --force-update
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
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

function deploy_prometheus()
{
  #
  # Avoid doing this more than once
  # We may have multiple commons running on the same k8s cluster,
  # but we only have one prometheus.
  #
  helm_repository
  if (! g3kubectl --namespace=monitoring get deployment prometheus-server > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then
    if (! g3kubectl get namespace monitoring> /dev/null 2>&1);
    then
      g3kubectl create namespace monitoring
      g3kubectl label namespace monitoring app=prometheus
    fi

    if (g3kubectl --namespace=monitoring get deployment prometheus-server > /dev/null 2>&1);
    then
      #delete_prometheus
      echo "skipping delete"
    fi
    if ! g3kubectl get storageclass prometheus > /dev/null 2>&1; then
      g3kubectl apply -f "${GEN3_HOME}/kube/services/monitoring/prometheus-storageclass.yaml"
    fi
    if [ "$argocd" = true ]; then
    g3kubectl apply -f "$GEN3_HOME/kube/services/monitoring/prometheus-application.yaml" --namespace=argocd
    else
    gen3 arun helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring -f "${GEN3_HOME}/kube/services/monitoring/values.yaml" 
    fi
    deploy_thanos
  else
    gen3_log_info "Prometheus is already installed, use --force to try redeploying"
  fi
}


# function deploy_grafana()
# {
#   helm_repository
#   if (! g3kubectl get namespace grafana > /dev/null 2>&1);
#   then
#     g3kubectl create namespace grafana
#     g3kubectl label namespace grafana app=grafana
#   fi

#   #create_grafana_secrets
#   TMPGRAFANAVALUES=$(mktemp -p "$XDG_RUNTIME_DIR" "grafana.json_XXXXXX")
#   ADMINPASS=$(g3kubectl get secrets grafana-admin -o json |jq .data.credentials -r |base64 -d)
#   yq '.adminPassword = "'${ADMINPASS}'"' "${GEN3_HOME}/kube/services/monitoring/grafana-values.yaml" --yaml-output > ${TMPGRAFANAVALUES}
#   # curl -o grafana-values.yaml https://raw.githubusercontent.com/helm/charts/master/stable/grafana/values.yaml

#   if (! g3kubectl --namespace=grafana get deployment grafana > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then
#     if ( g3kubectl --namespace=grafana get deployment grafana > /dev/null 2>&1);
#     then
#       delete_grafana
#     fi
    
#     local HOSTNAME
#     HOSTNAME=$(gen3 api hostname)
    
#     g3k_kv_filter "${TMPGRAFANAVALUES}" DOMAIN ${HOSTNAME} |  gen3 arun helm upgrade --install grafana stable/grafana  --namespace grafana -f -
#     gen3 kube-setup-revproxy
#   else
#     echo "Grafana is already installed, use --force to try redeploying"
#   fi
# }

function deploy_thanos() {
  if  [[ -z $vpc_name ]]; then
    local vpc_name="$(gen3 api environment)"
  fi
  roleName="$vpc_name-thanos-role"
  saName="thanos"
  bucketName="$vpc_name-thanos-bucket"
  gen3 s3 create "$bucketName"
  gen3 awsrole create "$roleName" "$saName" "monitoring" || return 1
  gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name ${roleName} || true
  thanosValuesFile="$XDG_RUNTIME_DIR/thanos.yaml"
  thanosValuesTemplate="${GEN3_HOME}/kube/services/monitoring/thanos.yaml"
  g3k_kv_filter $thanosValuesTemplate S3_BUCKET $bucketName > $thanosValuesFile
  g3kubectl delete secret -n monitoring thanos-objstore-config || true
  g3kubectl create secret generic -n monitoring thanos-objstore-config --from-file="$thanosValuesFile"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/monitoring/thanos-deploy.yaml"
}

command=""
if [[ $# -gt 0 && ! "$1" =~ ^-*force ]]; then
  command="$1"
  shift
fi
case "$command" in
  prometheus)
    deploy_prometheus "$@"
    ;;
  # grafana)
  #   deploy_grafana "$@"
  #   ;;
  *)
    deploy_prometheus "$@"
    # deploy_grafana "$@"
    ;;
esac
