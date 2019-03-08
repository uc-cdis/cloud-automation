#!/bin/bash
#
# Deploy workspace-token-service into existing commons,
# this is an optional service that's not part of gen3 core services

_KUBE_SETUP_WTS=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
source "${_KUBE_SETUP_WTS}/../lib/kube-setup-init.sh"

setup_creds() {
    echo "check wts secret"
    if ! g3kubectl describe secret wts-g3auto | grep appcreds.json > /dev/null 2>&1; then
        credsPath="$(gen3_secrets_folder)/g3auto/wts/appcreds.json"
        if [ -f "$credsPath" ]; then
            gen3 secrets sync
            return 0
        fi
        hostname=$(g3kubectl get configmaps/global -o=jsonpath='{.data.hostname}')
        echo "creating fence oidc client"
        secrets=$(g3kubectl exec $(g3k pod fence) -- fence-create client-create --client wts --urls "https://${hostname}/wts/oauth2/authorize" --username wts --auto-approve | tail -1)
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
        if ! g3kubectl get secret wts-g3auto > /dev/null 2>&1; then
            echo "create database"
            if ! gen3 db setup wts; then
                echo "Failed setting up database for workspace token service"
                exit 1
            fi
        fi
        echo "create wts-secret"
        mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/wts"
        cat - > "$credsPath" <<EOM
        {
            "oidc_client_id": "$client_id",
            "oidc_client_secret": "$client_secret",
            "encryption_key": "$encryption_key",
            "secret_key": "$secret_key",
            "fence_base_url": "https://${hostname}/user/",
            "wts_base_url": "https://${hostname}/wts/"
        }
EOM
        gen3 secrets sync
    fi
}
# deploy wts
setup_creds
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/serviceaccount.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/role-wts.yaml"
context=$(g3kubectl config view -o template --template='{{ index . "current-context" }}')
namespace="$(gen3 db namespace)"
g3k_kv_filter ${GEN3_HOME}/kube/services/wts/rolebinding-wts.yaml WTS_BINDING "name: wts-binding-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -

gen3 roll wts
g3kubectl apply -f "${GEN3_HOME}/kube/services/wts/wts-service.yaml"

echo "The wts services has been deployed onto the k8s cluster."

