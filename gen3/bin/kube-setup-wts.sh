#!/bin/bash
#
# Deploy workspace-token-service into existing commons,
# this is an optional service that's not part of gen3 core services

_KUBE_SETUP_WTS=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_WTS}/../lib/kube-setup-init.sh"


echo "check wts secret"
if ! g3kubectl get secret wts-secret > /dev/null 2>&1; then
    hostname=$(g3kubectl get configmaps/global -o=jsonpath='{.data.hostname}')
    secrets=$(kubectl exec $(g3k pod fence) -- fence-create client-create --client wts --urls "https://${hostname}/wts/oauth2/authorize" --username wts --auto-approve)
    # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
    if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
        echo "Failed generating oidc client for workspace token service: "
        echo $secrets
        exit 1
    fi
    client_id="${BASH_REMATCH[2]}"
    client_secret="${BASH_REMATCH[3]}"
    encryption_key="$(random_alphanumeric 32 | base64)"
    secret_key="$(random_alphanumeric 32 | base64)"
    echo "create wts-secret"
    kubectl create secret generic wts-secret --type=string --from-literal=OIDC_CLIENT_ID='$client_id' --from-literal=OIDC_CLIENT_SECRET='$client_secret' --from-literal=ENCRYPTION_KEY='$encryption_key' --from-literal=SECRET_KEY='$secret_key' --from-literal=FENCE_BASE_URL='${hostname}/user/' --from-literal=WTS_BASE_URL='${hostname}/wts/' --from-literal=SQLALCHEMY_DATABASE_URI='sqlite:////mnt/data/wts.db'

fi
# deploy wts
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/storageclass.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/serviceaccount.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/role-wts.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/rolebinding-wts.yaml"
gen3 roll wts
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/wts-service.yaml"

echo "The wts services has been deployed onto the k8s cluster."

