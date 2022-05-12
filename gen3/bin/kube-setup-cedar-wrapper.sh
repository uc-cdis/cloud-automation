source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

g3kubectl apply -f "${GEN3_HOME}/kube/services/cedar-wrapper/cedar-wrapper-service.yaml"
gen3 roll cedar-wrapper
