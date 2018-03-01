#!/bin/bash
#
# The optional jupyterhub setup for workspaces

set -e

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-jupyterhub.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}

# If you change this name you need to change it in the jupyterhub-config.yaml too
namespaceName="jupyter_pods"

# Create the namespace for user pods
if ! kubectl get namespace "$namespaceName" > /dev/null 2>&1; then
  echo "Creating k8s namespace: ${namespaceName}" 
  kubectl create namespace "${namespaceName}"
else
  echo "I think k8s namespace ${namespaceName} already exists"
fi


kubectl apply -f services/jupyterhub/jupyterhub-config.yaml
kubectl apply -f services/jupyterhub/jupyterhub-service.yaml
kubectl apply -f services/jupyterhub/jupyterhub-storage.yaml
kubectl apply -f services/jupyterhub/jupyterhub-deployment.yaml

