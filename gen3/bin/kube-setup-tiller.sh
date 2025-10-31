#!/bin/bash
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"
    
if g3kubectl get deployments/tiller-deploy --namespace=kube-system > /dev/null 2>&1; then
  if helm version --short | grep v3 > /dev/null 2>&1; then
    if ! helm plugin list | grep 2to3 > /dev/null 2>&1; then
      helm plugin install https://github.com/helm/helm-2to3.git
    fi
    if ( g3kubectl --namespace=prometheus get deployment prometheus-server > /dev/null 2>&1) || ( g3kubectl --namespace=grafana get deployment grafana > /dev/null 2>&1); then
      if ! helm ls --namespace grafana | grep grafana > /dev/null 2>&1; then
        echo "Migrating grafana to helm3."
        helm 2to3 convert grafana 
      fi
      if ! helm ls --namespace prometheus | grep prometheus > /dev/null 2>&1; then
        echo "Migrating prometheus to helm3."
        helm 2to3 convert prometheus
      fi
    fi
    # delete tiller and other helm2 data/configs
    helm 2to3 cleanup --skip-confirmation
  fi
else
  echo "tiller is already removed."
  exit 1
fi
