source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets


kayako_api_key_file="$(gen3_secrets_folder)/kayako_api_key.txt"
kayako_secret_key_file="$(gen3_secrets_folder)/kayako_secret_key.txt"

if [[ ! -f "$kayako_api_key_file" ]]; then
    gen3_log_err "No kayako api key present in ${kayako_api_key_file}, not rolling kayako wrapper"
    exit 1
fi
if [[ ! -f "$kayako_secret_key_file" ]]; then
    gen3_log_err "No kayako secret key present in ${kayako_secret_key_file}, not rolling kayako wrapper"
    exit 1
fi

if g3kubectl get secret kayako-service-api-key > /dev/null 2>&1; then
    g3kubectl delete secret kayako-service-api-key
fi
if g3kubectl get secret kayako-service-secret-key > /dev/null 2>&1; then
    g3kubectl delete secret kayako-service-secret-key
fi

g3kubectl create secret generic "kayako-service-api-key" --from-file=kayako_api_key.txt=${kayako_api_key_file}
g3kubectl create secret generic "kayako-service-secret-key" --from-file=kayako_secret_key.txt=${kayako_secret_key_file}

g3kubectl apply -f "${GEN3_HOME}/kube/services/kayako-wrapper/kayako-wrapper-service.yaml"
gen3 roll kayako-wrapper

gen3_log_info "The kayako wrapper service has been deployed onto the kubernetes cluster"
