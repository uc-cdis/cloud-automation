#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

setup_ecr_access_job() {
    if g3kubectl get configmap manifest-global > /dev/null; then
      ecrRoleArn=$(g3kubectl get configmap manifest-global -o jsonpath={.data.ecr-access-job-role-arn})
    fi
    if [ -z "$ecrRoleArn" ]; then
      gen3_log_err "Missing 'global.ecr-access-job-role-arn' configuration in manifest.json"
      return 1
    fi

    local saName="ecr-access-job-sa"
    if ! g3kubectl get sa "$saName" > /dev/null 2>&1; then
      tempFile="ecr-access-job-policy.json"
      cat - > $tempFile <<EOM
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadDynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/*"
    },
    {
      "Sid": "AssumeEcrRole",
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "$ecrRoleArn"
    }
  ]
}
EOM
      local role_name
      if ! role_name="$(gen3 iam-serviceaccount -c "${saName}" -p $tempFile)" || [[ -z "$role_name" ]]; then
        gen3_log_err "Failed to create iam service account"
        rm $tempFile
        return 1
      fi
      rm $tempFile
      gen3_log_info "created service account '${saName}' and role '${role_name}'"
    else
      gen3_log_info "service account '${saName}' already exist"
    fi
}

setup_ecr_access_job

# Run every hour, at the top of the hour
gen3 job cron ecr-access "0 * * * *"

cat <<EOM
The ecr-access cronjob has been configured.
EOM
