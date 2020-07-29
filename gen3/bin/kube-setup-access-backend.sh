#!/bin/bash
#
# Setup bucket and creds for access backend
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

#
# access-backend requires dynamodb
#
setup_access_backend() {
  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/access-backend"
  if ! secret="$(g3kubectl get secret access-backend-g3auto -o json 2> /dev/null)" || "false" == "$(jq -r '.data | has("creds.json")' <<< "$secret")"; then # pragma: allowlist secret
    # access-backend-g3auto secret does not exist # pragma: allowlist secret
    # maybe we just need to sync secrets from the file system
    if [[ -f "${secretsFolder}/creds.json" ]]; then
        gen3 secrets sync "setup access-backend secrets"
    else
      mkdir -p "$secretsFolder"
    fi
  fi
  gen3_log_info "setting up access-backend service ..."

  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup .env file that access-backend-service consumes
  if [[ ! -f "$secretsFolder/access-backend.env" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/access-backend"
    # if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
    #   if ! gen3 db setup access-backend; then
    #     gen3_log_err "Failed setting up database for access-backend service"
    #     return 1
    #   fi
    # fi
    touch "$secretsFolder/dbcreds.json"
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi

#     cat - > "cors.json" <<EOM
# {
#   "CORSRules": [
#     {
#       "AllowedOrigins": ["$allowedOrigin"],
#       "AllowedHeaders": ["*"],
#       "AllowedMethods": ["PUT", "POST", "DELETE"],
#       "MaxAgeSeconds": 3000,
#       "ExposeHeaders": ["x-amz-server-side-encryption"]
#     },
#     {
#       "AllowedOrigins": ["*"],
#       "AllowedHeaders": ["Authorization"],
#       "AllowedMethods": ["GET"],
#       "MaxAgeSeconds": 3000
#     }
#   ]
# }
# EOM

#     echo "enabling CORS on the bucket"
#     aws s3api put-bucket-cors --bucket "$bucketName" --cors-configuration file://cors.json

    cat - > "access-backend-aws-policy.json" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GlobalDynamodbAdmin",
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "arn:aws:dynamodb:::table/*"
        }
    ]
}
EOM
    local saName=$(echo "access-${hostname//./-}" | head -c63)
    if ! g3kubectl get sa "$saName" > /dev/null 2>&1; then
      local role_name
      if ! role_name="$(gen3 iam-serviceaccount -c "${saName}" -p ./access-backend-aws-policy.json)" || [[ -z "$role_name" ]]; then
        gen3_log_err "Failed to create iam service account"
        return 1
      fi
      gen3_log_info "created service account '${saName}' with dynamodb access"
      gen3_log_info "created role name '${role_name}'"
      # TODO do I need the following: ???
      # gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${role_name}"
      # gen3_log_info "attached read-write bucket policy to '${bucketName}' for role '${role_name}'"
    fi

    cat - > "$secretsFolder/access-backend.env" <<EOM
DEBUG=False
extra_args=$(jq -r .extra_args < "$secretsFolder/dbcreds.json")
ADMIN_USERS=
GH_ORG=
GH_REPO=
GH_FILE=
GH_KEY=
JWT_ISSUERS=
REVIEW_REQUESTS_ACCESS=
JWT_SIGNING_KEYS=
EOM
    gen3 secrets sync 'setup access-backend credentials'
  fi
}

if [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
    setup_access_backend
fi

cat <<EOM
The access-backend bucket has been configured and the secret setup for use by access backend.
EOM
