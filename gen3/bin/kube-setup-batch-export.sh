#!/bin/bash
#
# batch export sower job setup


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


if ! g3kubectl get secrets | grep batch-export-g3auto /dev/null 2>&1; then
  hostname="$(gen3 api hostname)"
  ref_hostname=$(echo "$hostname" | sed 's/\./-/g')
  bucket_name="${ref_hostname}-batch-export-bucket"
  sa_name="batch-export-sa"

  gen3_log_info "Creating batch export bucket"

  if [[ -z "$JENKINS_HOME" ]]; then
    gen3 s3 create $bucket_name

    cat - > "export-job-aws-policy.json" <<EOM
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
                "arn:aws:s3:::$bucket_name/*",
                "arn:aws:s3:::$bucket_name"
            ]
        }
    ]
}
EOM
    if ! g3kubectl get sa "$sa_name" > /dev/null 2>&1; then
      if ! gen3 iam-serviceaccount -c "${sa_name}" -p ./export-job-aws-policy.json; then
        gen3_log_err "Failed to create iam service account"
        return 1
      fi
      gen3_log_info "created service account 'batch-export-sa' with s3 access"
      gen3_log_info "created role name '${role_name}'"
    fi

  gen3_log_info "creating batch-export-g3auto configmap"
  kubectl create configmap batch-export-g3auto --from-literal=bucket_name="$bucket_name"
  fi
fi
