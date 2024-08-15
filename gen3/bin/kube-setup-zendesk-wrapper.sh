source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if ! g3kubectl get secrets/zendesk-g3auto > /dev/null 2>&1; then
    gen3_log_err "No zendesk-g3auto secret, not rolling zendesk wrapper"
    exit 1
fi

if ! gen3 secrets decode zendesk-g3auto zendesk_api_key.txt> /dev/null 2>&1; then
    gen3_log_err "No zendesk api key present in zendesk-g3auto secret, not rolling zendesk wrapper"
    exit 1
fi

if ! gen3 secrets decode zendesk-g3auto zendesk_email.txt> /dev/null 2>&1; then
    gen3_log_err "No zendesk email present in zendesk-g3auto secret, not rolling zendesk wrapper"
    exit 1
fi


g3kubectl apply -f "${GEN3_HOME}/kube/services/zendesk-wrapper/zendesk-wrapper-service.yaml"
gen3 roll zendesk-wrapper

gen3_log_info "The zendesk wrapper service has been deployed onto the kubernetes cluster"
