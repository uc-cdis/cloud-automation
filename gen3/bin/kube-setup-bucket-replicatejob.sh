#!/bin/bash
#
source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! g3kubectl describe secret bucketreplicate-g3auto | grep credentials > /dev/null 2>&1; then
  if ! g3kubectl get serviceaccounts | grep batch-operations-account > /dev/null 2>&1; then
    tempFile="$(gen3_secrets_folder)/replicatePolicy"
    cat - > "$tempFile" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:CreatePolicy",
                "iam:UpdateAssumeRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:DeletePolicy",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:ListRolePolicies",
                "iam:GetRole",
                "iam:PassRole"
            ],
            "Resource": [
                "arn:aws:iam::*:policy/*",
                "arn:aws:iam::*:role/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
              "iam:ListRoles",
              "s3:*"
            ],
            "Resource": "*"
        }
    ]
}
EOM
    gen3 iam-serviceaccount -c batch-operations-account -p $tempFile
    rm $tempFile
  fi
  mkdir -p $(gen3_secrets_folder)/g3auto/bucketreplicate
  credsFile="$(gen3_secrets_folder)/g3auto/bucketreplicate/credentials"
  if [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; then
    roleArn=$(g3kubectl get serviceaccounts batch-operations-account -o json | jq -r '.metadata.annotations["eks.amazonaws.com/role-arn"]')
    gen3_log_info "initializing bucketreplicate credentials. You will still need to fill in source and destination account credentials for cross account replicates."
    cat - > "$credsFile" <<EOM
[default]
output = json
region = us-east-1
role_session_name = default
role_arn = $roleArn
web_identity_token_file = /var/run/secrets/eks.amazonaws.com/serviceaccount/..data/token

[source]
aws_access_key_id=<Access key for source account>
aws_secret_access_key=<Secret for source account>

[destination]
aws_access_key_id=<Access key for destination account>
aws_secret_access_key=<Secret for destination account>
EOM
    gen3 secrets sync "initialize bucketreplicate/credentials"
  fi
fi
