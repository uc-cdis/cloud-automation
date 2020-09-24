#!/bin/bash
#
# Setup bucket and creds for sower jobs
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

#
# sower-jobs require access to an S3 bucket
#
setup_sower_jobs() {
  local secret
  local secretsFolder="$(gen3_secrets_folder)/g3auto/sower-jobs"
  if ! secret="$(g3kubectl get secret sower-jobs-g3auto -o json 2> /dev/null)" \
    || "false" == "$(jq -r '.data | has("creds.json")' <<< "$secret")"; then
    # sower-jobs-g3auto secret does not exist
    # maybe we just need to sync secrets from the file system
    if [[ -f "${secretsFolder}/creds.json" ]]; then
        gen3 secrets sync "setup sower-jobs secrets"
    else
      mkdir -p "$secretsFolder"
    fi
  fi
  if ! secret="$(g3kubectl get secret sower-jobs-g3auto -o json 2> /dev/null)" \
    || "false" == "$(jq -r '.data | has("creds.json")' <<< "$secret")"; then
    gen3_log_info "setting up secrets for sower jobs"
    #
    # sower-jobs-g3auto secret still does not exist
    # we need to setup an S3 bucket and IAM creds
    # let's avoid creating multiple buckets for different
    # deployments to the same k8s cluseter (dev, etc)
    #
    local accountNumber
    local hostname
    local bucketName
    if ! accountNumber="$(aws sts get-caller-identity --output text --query 'Account')"; then
      gen3_log_err "could not determine account numer"
    fi
    if ! hostname="$(gen3 api hostname)"; then
      gen3_log_err "could not determine hostname from manifest-global - bailing out of sower-jobs setup"
      return 1
    fi

    # try to come up with a unique but composable bucket name
    bucketName=$(echo "jobs-${accountNumber}-${hostname//./-}" | head -c 50)
    if aws s3 ls --page-size 1 "s3://${bucketName}" > /dev/null 2>&1; then
      gen3_log_info "${bucketName} s3 bucket already exists - probably in use by another namespace - copy the creds from there to $(gen3_secrets_folder)/g3auto/sower-jobs"
      # continue on ...
    elif ! gen3 s3 create "${bucketName}"; then
      gen3_log_err "maybe failed to create bucket ${bucketName}, but maybe not, because the terraform script is flaky"
    fi

    local allowedOrigin
    allowedOrigin="https://$hostname"

    cat - > "cors.json" <<EOM
{
  "CORSRules": [
    {
      "AllowedOrigins": ["$allowedOrigin"],
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT", "POST", "DELETE"],
      "MaxAgeSeconds": 3000,
      "ExposeHeaders": ["x-amz-server-side-encryption"]
    },
    {
      "AllowedOrigins": ["*"],
      "AllowedHeaders": ["Authorization"],
      "AllowedMethods": ["GET"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOM

    echo "enabling CORS on the bucket"
    aws s3api put-bucket-cors --bucket "$bucketName" --cors-configuration file://cors.json

    cat - > "sower-jobs-aws-policy.json" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObjectLegalHold",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::jobs-*/*",
                "arn:aws:s3:::jobs-*"
            ]
        }
    ]
}
EOM
    local saName=$(echo "jobs-${hostname//./-}" | head -c63)
    if ! g3kubectl get sa "$saName" > /dev/null 2>&1; then
      local role_name
      if ! role_name="$(gen3 iam-serviceaccount -c "${saName}" -p ./sower-jobs-aws-policy.json)" || [[ -z "$role_name" ]]; then
        gen3_log_err "Failed to create iam service account"
        return 1
      fi
      gen3_log_info "created service account '${saName}' with s3 access"
      gen3_log_info "created role name '${role_name}'"
      # TODO do I need the following: ???
      gen3 s3 attach-bucket-policy "$bucketName" --read-write --role-name "${role_name}"
      gen3_log_info "attached read-write bucket policy to '${bucketName}' for role '${role_name}'"
    fi

    local credsBak="$(mktemp "$XDG_RUNTIME_DIR/creds.json_XXXXXX")"
    local indexdPassword=""
    local updateIndexd=false
    # create new indexd user if necessary
    if ! indexdPassword="$(jq -e -r .indexd.user_db.diirm < "$(gen3_secrets_folder)/creds.json" 2> /dev/null)" \
      || [[ -z "$indexdPassword" && "$indexdPassword" == null ]]; then
      indexdPassword="$(gen3 random)"
      cp "$(gen3_secrets_folder)/creds.json" "$credsBak"
      jq -r --arg password "$indexdPassword" '.indexd.user_db.diirm=$password' < "$credsBak" > "$(gen3_secrets_folder)/creds.json"
      /bin/rm "$credsBak"
      updateIndexd=true
    fi

    cat - > "${secretsFolder}/creds.json" <<EOM
{
  "index-object-manifest": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "bucket": "$bucketName",
    "indexd_user": "diirm",
    "indexd_password": "$indexdPassword"
  },
  "download-indexd-manifest": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "bucket": "$bucketName"
  },
  "get-dbgap-metadata": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "bucket": "$bucketName"
  },
  "ingest-metadata-manifest": {
    "job_requires": {
      "arborist_url": "http://arborist-service",
      "job_access_req": []
    },
    "bucket": "$bucketName"
  }
}
EOM
    gen3 secrets sync 'setup sower-jobs credentials'
    if [[ "$updateIndexd" != "false" ]]; then
      gen3 job run indexd-userdb
    fi
  fi
}

if [[ -f "$(gen3_secrets_folder)/creds.json" && -z "$JENKINS_HOME" ]]; then
    setup_sower_jobs
fi

cat <<EOM
The sower-jobs bucket has been configured and the secret setup for use by sower jobs.
EOM
