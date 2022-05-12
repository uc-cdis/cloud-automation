source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

g3kubectl apply -f "${GEN3_HOME}/kube/services/cedar-wrapper/cedar-wrapper-service.yaml"
gen3 roll cedar-wrapper


if [[ -f "$(gen3_secrets_folder)/g3auto/cedar/apikey.txt" ]]; then
    gen3_log_err "No CEDAR api key present in $(gen3_secrets_folder)/g3auto/cedar/apikey.txt"
fi