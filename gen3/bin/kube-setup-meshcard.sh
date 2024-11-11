source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

g3kubectl apply -f "${GEN3_HOME}/kube/services/kayako-wrapper/meshcard-service.yaml"
gen3 roll meshcard

gen3_log_info "The meshcard service has been deployed onto the kubernetes cluster"
