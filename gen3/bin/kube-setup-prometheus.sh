#!/bin/bash
#
#  Prometheus would let us gather some useful metrics from the cluster that should help us out troubleshooting and improving
#

# Load the basics

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping fluentd setup: $JENKINS_HOME"
  exit 0
fi


function delete_prometheus()
{
      gen3 arun helm delete prometheus
      gen3 arun helm del --purge prometheus
}

function delete_grafana()
{
      gen3 arun helm delete grafana
      gen3 arun helm del --purge grafana
}

function create_grafana_secrets()
{

  if ! g3kubectl get secrets/grafana-admin > /dev/null 2>&1; then
    credsFile=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
    creds="$(base64 /dev/urandom | head -c 12)"
    if [[ "$creds" != null ]]; then
      echo ${creds} >> "$credsFile"
      g3kubectl create secret generic grafana-admin "--from-file=credentials=${credsFile}"
      rm -f ${credsFile}
    else
      echo "WARNING: there was an error creating the secrets for grafana"
    fi
  fi
}

function deploy_prometheus()
{
  #
  # Avoid doing this more than once
  # We may have multiple commons running on the same k8s cluster,
  # but we only have one prometheus.
  #
  if (! g3kubectl --namespace=prometheus get deployment prometheus-server > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then
    if (! g3kubectl get namespace prometheus > /dev/null 2>&1);
    then
      g3kubectl create namespace prometheus
    fi

    if ( g3kubectl --namespace=prometheus get deployment prometheus-server > /dev/null 2>&1);
    then
      delete_prometheus
    fi
    # We need to give helm permission to do certain stuff for us, including some admin access so we can deploy prometheus
    g3kubectl apply -f "${GEN3_HOME}/kube/services/monitoring/helm-rbac.yaml"

    # now prometheus
    g3kubectl apply -f "${GEN3_HOME}/kube/services/monitoring/prometheus-storageclass.yaml"

    local HOSTNAME
    HOSTNAME=$(g3kubectl get configmaps manifest-global -o jsonpath="{.data.hostname}")
    sed "s/DOMAIN/${HOSTNAME}/" "${GEN3_HOME}/kube/services/monitoring/prometheus-values.yaml" |  gen3 arun helm install  stable/prometheus --name prometheus --namespace prometheus -f --
  else
    echo "Prometheus is already installed, use --force to try redeploying"
  fi
}


function deploy_grafana()
{
  if (! g3kubectl get namespace grafana > /dev/null 2>&1);
  then
    g3kubectl create namespace grafana
  fi

  #create_grafana_secrets
  tmpGrafanaValues=$(mktemp -p "$XDG_RUNTIME_DIR" "creds.json_XXXXXX")
  adminPass=$(g3kubectl get secrets grafana-admin -o json |jq .data.credentials -r |base64 -d)
  yq '.adminPassword = "'${adminPass}'"' "${GEN3_HOME}/kube/services/monitoring/grafana-values.yaml" --yaml-output > ${tmpGrafanaValues}
  # curl -o grafana-values.yaml https://raw.githubusercontent.com/helm/charts/master/stable/grafana/values.yaml

  if (! g3kubectl --namespace=grafana get deployment grafana > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then
    if ( g3kubectl --namespace=grafana get deployment grafana > /dev/null 2>&1);
    then
      delete_grafana
    fi
    
    #gen3 arun helm install -f "${GEN3_HOME}/kube/services/monitoring/grafana-values.yaml" stable/grafana --name grafana --namespace grafana
    gen3 arun helm install -f "${tmpGrafanaValues}" stable/grafana --name grafana --namespace grafana
  else
    echo "Grafana is already installed, use --force to try redeploying"
  fi
}


deploy_prometheus ${1}
deploy_grafana ${1} 
