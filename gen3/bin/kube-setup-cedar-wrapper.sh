source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if ! g3kubectl get secrets/cedar-g3auto > /dev/null 2>&1; then
    gen3_log_err "No cedar-g3auto secret, not rolling CEDAR wrapper"
    return 1
fi

if ! gen3 secrets decode cedar-g3auto cedar_api_key.txt > /dev/null 2>&1; then
    gen3_log_err "No CEDAR api key present in cedar-g3auto secret, not rolling CEDAR wrapper"
    return 1
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/cedar-wrapper/cedar-wrapper-service.yaml"
gen3 roll cedar-wrapper

gen3_log_info "The CEDAR wrapper service has been deployed onto the kubernetes cluster"
