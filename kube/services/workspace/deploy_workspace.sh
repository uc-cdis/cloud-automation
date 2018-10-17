#!/bin/bash
#
# Create the '"${userName}"' user, k8s config, etc,
# so that we can give a person a '"${userName}"' kubeconfig
# that will allow them to deploy and manage services to our
# cluster within the 'workspace' k8s namespace.
#
# see https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
# see kube/README.md
#

set -e

namespaceName="workspace"
userName="worker"

if [ ! -f credentials/ca.pem ]; then
  echo "No ./credentials/ca.pem CA root certificate - run this script from within ~/VPC_NAME"
fi

if [ -z "${KUBECONFIG}" ]; then
  if [ -f ./kubeconfig ]; then
    export KUBECONFIG=./kubeconfig
  else
    echo "ERROR: KUBECONFIG not configured - bailing out"
    exit 1
  fi
fi

if [ ! -f "credentials/${userName}.crt" ]; then
  echo "Creating credentials/${userName}.crt"
  #
  # creat a limitted-access k8s user with cert-based auth
  #
  openssl genrsa -out "credentials/${userName}.key" 2048
  openssl req -new -key "credentials/${userName}.key" -out "credentials/${userName}.csr" -subj "/CN=${userName}/O=cdis"
  openssl x509 -req -in "credentials/${userName}.csr" -CA credentials/ca.pem -CAkey credentials/ca-key.pem -CAcreateserial -out "credentials/${userName}.crt" -days 500

  cluster=$(g3kubectl config get-clusters | tail -1)   
  kubectl config set-credentials "${userName}" --client-certificate="credentials/${userName}.crt" --client-key="credentials/${userName}.key" 
else
  echo "credentials/${userName}.crt already exists"
fi

if ! kubectl get namespace "$namespaceName" > /dev/null 2>&1; then
  echo "Creating k8s namespace: ${namespaceName}" 
  kubectl create namespace "${namespaceName}"
else
  echo "I think k8s namespace ${namespaceName} already exists"
fi

kubectl config set-context "${userName}-context" --cluster="${cluster}"  --namespace="${namespaceName}" --user="${userName}"

cp kubeconfig "kubeconfig_${userName}"
sed -i "s/current-context: .*/current-context: ${userName}-context/" "kubeconfig_${userName}"

#
# Bind the new user to a role - ...
# You have to write some new yaml files if you change the username or namespace ...
#   
kubectl apply -f "services/workspace/role-${userName}.yaml"
kubectl apply -f "services/workspace/rolebinding-${userName}.yaml"

# Tar bundle that we can install on a VM with access to controller.internal.io to run kubectl
echo "Generating kubeconfig tar suitcase that you can unzip to give a user access to the cluster as ${userName}: kubeconfig_${userName}.tar.xz"
echo "Note: the host must have a route to the k8s api, and should reference the .internal.io DNS"
tar cvJf kubeconfig_"${userName}".tar.xz kubeconfig_"${userName}" credentials/ca.pem credentials/"${userName}".*
