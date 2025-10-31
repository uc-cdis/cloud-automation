source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if ! g3kubectl get secrets/kayako-g3auto > /dev/null 2>&1; then
    gen3_log_err "No kayako-g3auto secret, not rolling Kayako wrapper"
    return 1
fi

if ! gen3 secrets decode kayako-g3auto kayako_api_key.txt> /dev/null 2>&1; then
    gen3_log_err "No Kayako api key present in kayako-g3auto secret, not rolling Kayako wrapper"
    return 1
fi

if ! gen3 secrets decode kayako-g3auto kayako_secret_key.txt> /dev/null 2>&1; then
    gen3_log_err "No Kayako secret key present in kayako-g3auto secret, not rolling Kayako wrapper"
    return 1
fi


g3kubectl apply -f "${GEN3_HOME}/kube/services/kayako-wrapper/kayako-wrapper-service.yaml"
gen3 roll kayako-wrapper

gen3_log_info "The kayako wrapper service has been deployed onto the kubernetes cluster"
