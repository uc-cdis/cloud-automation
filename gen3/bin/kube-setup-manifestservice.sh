#!/bin/bash
#
# Deploy manifestservice into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to commons that have Export to Workspace functionality

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets


hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
bucketname="manifest-${hostname//./-}"
gen3 s3 create "$bucketname"
# this will fail if manifest-user does not exist ... I think -Reuben
gen3 s3 attach-bucket-policy "$bucketname" --read-write --user-name manifest_bot || true


credsFile="$(gen3_secrets_folder)/g3auto/manifestservice/creds.json"
if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
  gen3_log_err "manifestservice creds.json not initialized - add AWS creds"
  cat - > "$credsFile" <<EOM
{
  "manifest_bucket_name": "$bucketName",
  "hostname": "$hostname"
}
EOM
  gen3 secrets sync "initialize manifestservice/creds.json"
fi


# deploy manifest-service
gen3 roll manifestservice
g3kubectl apply -f "${GEN3_HOME}/kube/services/manifestservice/manifestservice-service.yaml"

cat <<EOM
The manifest service has been deployed onto the k8s cluster.
EOM
