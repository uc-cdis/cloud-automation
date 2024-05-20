source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

create_client_and_secret() {
    local hostname=$(gen3 api hostname)
    local client_name="cedar_ingest_client"
    gen3_log_info "kube-setup-cedar-wrapper" "creating fence ${client_name} for $hostname"
    # delete any existing fence cedar clients
    g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client ${client_name} > /dev/null 2>&1
    local secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client ${client_name} --grant-types client_credentials | tail -1)
    # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
    if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
        gen3_log_err "kube-setup-cedar-wrapper" "Failed generating ${client_name}"
        return 1
    else
        local client_id="${BASH_REMATCH[2]}"
        local client_secret="${BASH_REMATCH[3]}"
        gen3_log_info "Create cedar-client secrets file"
        cat - <<EOM
{
  "client_id": "$client_id",
  "client_secret": "$client_secret"
}
EOM
    fi
}

setup_creds() {
    # check if new cedar client and secrets are needed"
    local cedar_creds_file="cedar_client_credentials.json"

    if gen3 secrets decode cedar-g3auto ${cedar_creds_file} > /dev/null 2>&1; then
        local have_cedar_client_secret="1"
    else
        gen3_log_info "No g3auto cedar-client key present in secret"
    fi

    local client_name="cedar_ingest_client"
    local client_list=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-list)
    local client_count=$(echo "$client_list=" | grep -cE "'name':.*'${client_name}'")
    gen3_log_info "CEDAR client count = ${client_count}"

    if [[ -z $have_cedar_client_secret ]] || [[ ${client_count} -lt 1 ]]; then
        gen3_log_info "Creating new cedar-ingest client and secret"
        local credsPath="$(gen3_secrets_folder)/g3auto/cedar/${cedar_creds_file}"
        if ! create_client_and_secret > $credsPath; then
            gen3_log_err "Failed to setup cedar-ingest secret"
            return 1
        else
            gen3 secrets sync
            gen3 job run usersync
        fi
    fi
}

[[ -z "$GEN3_ROLL_ALL" ]] && gen3 kube-setup-secrets

if ! g3kubectl get secrets/cedar-g3auto > /dev/null 2>&1; then
    gen3_log_err "No cedar-g3auto secret, not rolling CEDAR wrapper"
    return 1
fi

if [[ -n "$JENKINS_HOME" ]]; then
    gen3_log_info "Skipping cedar-client creds setup in non-adminvm environment"
else
    gen3_log_info "Checking cedar-client creds"
    setup_creds
fi

if ! gen3 secrets decode cedar-g3auto cedar_api_key.txt > /dev/null 2>&1; then
    gen3_log_err "No CEDAR api key present in cedar-g3auto secret, not rolling CEDAR wrapper"
    return 1
fi

g3kubectl apply -f "${GEN3_HOME}/kube/services/cedar-wrapper/cedar-wrapper-service.yaml"
gen3 roll cedar-wrapper

gen3_log_info "The CEDAR wrapper service has been deployed onto the kubernetes cluster"
