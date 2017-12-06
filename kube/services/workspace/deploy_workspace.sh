#!/bin/bash
#
# Create the 'worker' user, k8s config, etc,
# so that we can give a person a 'worker' kubeconfig
# that will allow them to deploy and manage services to our
# cluster within the 'workspace' k8s namespace.
#
# see https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
# see kube/README.md
#

set -e

if [ ! -f credentials/ca.pem ]; then
  echo "No ./credentials/ca.pem CA root certificate - run this script from within ~/VPC_NAME"
fi

#
# creat a limitted-access k8s user with cert-based auth
#
openssl genrsa -out credentials/worker.key 2048
openssl req -new -key credentials/worker.key -out credentials/worker.csr -subj '/CN=worker/O=cdis'
openssl x509 -req -in credentials/worker.csr -CA credentials/ca.pem -CAkey credentials/ca-key.pem -CAcreateserial -out credentials/worker.crt -days 500

cluster=$(kubectl config get-clusters | tail -1)   
kubectl config set-credentials worker --client-certificate=credentials/worker.crt --client-key=credentials/worker.key 

kubectl create namespace workspace
kubectl config set-context worker-context --cluster="${cluster}"  --namespace=workspace --user=worker

cp kubeconfig kubeconfig_worker
sed -i 's/current-context: .*/current-context: worker-context/' kubeconfig_worker
    
kubectl apply -f services/workspace/role-worker.yaml
kubectl apply -f services/workspace/rolebinding-worker.yaml

# Tar bundle that we can install on a VM with access to controller.internal.io to run kubectl
tar cvJf kubeconfig_worker.tar.xz kubeconfig_worker credentials/ca.pem credentials/worker.*
