source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

g3kubectl apply -f "${GEN3_HOME}/kube/services/frontend-framework/frontend-framework-service.yaml"
gen3 roll frontend-framework
