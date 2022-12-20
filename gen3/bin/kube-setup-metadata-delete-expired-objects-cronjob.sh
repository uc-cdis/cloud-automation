#!/bin/bash
#
# Deploy the `metadata-delete-expired-objects` cronjob.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

setup_config() {
  gen3_log_info "check metadata-delete-expired-objects secret"
  local secretsFolder="$(gen3_secrets_folder)/g3auto/metadata-delete-expired-objects"
  if [[ ! -f "$secretsFolder/config.json" ]]; then
    local hostname=$(gen3 api hostname)
    gen3_log_info "kube-setup-metadata-delete-expired-objects-job" "creating fence oidc client for $hostname"
    local secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client metadata-delete-expired-objects-job --grant-types client_credentials | tail -1)
    # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
    if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
        # try delete client
        g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client metadata-delete-expired-objects-job > /dev/null 2>&1
        secrets=$(g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client metadata-delete-expired-objects-job --grant-types client_credentials | tail -1)
        if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
            gen3_log_err "kube-setup-metadata-delete-expired-objects-job" "Failed generating oidc client: $secrets"
            return 1
        fi
    fi
    local client_id="${BASH_REMATCH[2]}"
    local client_secret="${BASH_REMATCH[3]}"

    gen3_log_info "create metadata-delete-expired-objects secret"
    mkdir -m 0700 -p "$(gen3_secrets_folder)/g3auto/metadata-delete-expired-objects"

    cat - > "$secretsFolder/config.json" <<EOM
{
    "hostname": "https://$hostname",
    "oidc_client_id": "$client_id",
    "oidc_client_secret": "$client_secret"
}
EOM
    gen3 secrets sync
  fi
}

setup_config

gen3_log_warn "!!! The 'metadata-delete-expired-objects-job' client must be granted access to (resource=/mds_gateway, method=access, service=mds_gateway) and (resource=/programs, method=delete, service=fence)"

# Run once a week on Sunday, 6:00PM Chicago time == Monday, 12:00AM UTC
gen3 job cron metadata-delete-expired-objects "0 0 * * 1"
