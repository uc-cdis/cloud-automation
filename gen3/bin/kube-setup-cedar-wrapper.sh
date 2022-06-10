source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets


cedar_api_key_file="$(gen3_secrets_folder)/cedar_api_key.txt"

if [[ ! -f "$cedar_api_key_file" ]]; then
    gen3_log_err "No CEDAR api key present in ${cedar_api_key_file}"
else
    if g3kubectl get secret cedar-service-api-key > /dev/null 2>&1; then
        g3kubectl delete secret cedar-service-api-key
    fi
    g3kubectl create secret generic "cedar-service-api-key" --from-file=cedar_api_key.txt=${cedar_api_key_file}
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/cedar-wrapper/cedar-wrapper-service.yaml"
gen3 roll cedar-wrapper

