#!/bin/bash
#
# Deploy pelicanjob into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to commons that have Export to PFB functionality

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! g3kubectl describe secret pelicanservice-g3auto | grep config.json > /dev/null 2>&1; then
  hostname="$(gen3 api hostname)"
  ref_hostname=$(echo "$hostname" | sed 's/\./-/g')
  bucketname="${ref_hostname}-pfb-export"
  awsuser="${ref_hostname}-pelican"
  mkdir -p $(gen3_secrets_folder)/g3auto/pelicanservice
  credsFile="$(gen3_secrets_folder)/g3auto/pelicanservice/config.json"

  if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
    gen3 s3 create "$bucketname"
    gen3 awsuser create "${ref_hostname}-pelican"
    gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name "${ref_hostname}-pelican"

    gen3_log_info "initializing pelicanservice config.json"
    user=$(gen3 secrets decode $awsuser-g3auto awsusercreds.json)
    key_id=$(jq -r .id <<< $user)
    access_key=$(jq -r .secret <<< $user)

    # setup fence OIDC client with client_credentials grant for access to MDS API
    hostname=$(gen3 api hostname)
    gen3_log_info "kube-setup-sower-jobs" "creating fence oidc client for $hostname"
    # Adding a fallback to `poetry run fence-create` to cater to fence containers with amazon linux.
    secrets=$(
      (g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client pelican-export-job --grant-types client_credentials | tail -1) 2>/dev/null || \
        g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-create --client pelican-export-job --grant-types client_credentials | tail -1
    )
    # secrets looks like ('CLIENT_ID', 'CLIENT_SECRET')
    if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
        # try delete client
        g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-delete --client pelican-export-job > /dev/null 2>&1 || \
        g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-delete --client pelican-export-job > /dev/null 2>&1
        secrets=$(
          (g3kubectl exec -c fence $(gen3 pod fence) -- fence-create client-create --client pelican-export-job --grant-types client_credentials | tail -1) 2>/dev/null || \
                g3kubectl exec -c fence $(gen3 pod fence) -- poetry run fence-create client-create --client pelican-export-job --grant-types client_credentials | tail -1
        )
        if [[ ! $secrets =~ (\'(.*)\', \'(.*)\') ]]; then
            gen3_log_err "kube-setup-sower-jobs" "Failed generating oidc client: $secrets"
            return 1
        fi
    fi
    pelican_export_client_id="${BASH_REMATCH[2]}"
    pelican_export_client_secret="${BASH_REMATCH[3]}"

    cat - > "$credsFile" <<EOM
{
  "manifest_bucket_name": "$bucketname",
  "hostname": "$hostname",
  "aws_access_key_id": "$key_id",
  "aws_secret_access_key": "$access_key",
  "fence_client_id": "$pelican_export_client_id",
  "fence_client_secret": "$pelican_export_client_secret"
}
EOM
    gen3 secrets sync "initialize pelicanservice/config.json"
  fi
fi

gen3_log_warn "!!! The 'pelican-export-job' client must be granted access to (resource=/mds_gateway, method=access, service=mds_gateway) for the Pelican Export job to function"
