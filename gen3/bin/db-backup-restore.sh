#!/bin/bash

set -e
set -x

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Variables
policyName="bucket_reader_writer_gen3_db_backup"
accountId=$(aws sts get-caller-identity --query "Account" --output text)
vpcName="$(gen3 api environment)"
nameSpace="$(gen3 db namespace)"
saName="${nameSpace}-dbbackup-sa"


# Create the S3 access policy - policy document
accessPolicy=$(cat <<-EOM
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::gen3-db-backups-*"
      ]
    }
  ]
}
EOM
)

# Create the S3 access policy from the policy document
# Check if the policy already exists
policyArn=$(aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)

if [ -z "$policyArn" ]; then
  # If the policy doesn't exist, create it
  policyArn=$(aws iam create-policy --policy-name "$policyName" --policy-document "$accessPolicy" --query "Policy.Arn" --output text)
fi

# create the Kubernetes Service Account, IAM role and attach the role to the policy
gen3 iam-serviceaccount -c $saName -p $policyArn || true

# create S3 bucket if not exist
bucketName="gen3-db-backups-${accountId}"

# Check if bucket already exists
if aws s3 ls "s3://$bucketName" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Bucket $bucketName does not exist, creating..."
    aws s3 mb "s3://$bucketName"
else
    echo "Bucket $bucketName already exists, skipping bucket creation."
fi


# trigger the backup job
#gen3 job run db-backup

# trigger the restore job
#gen3 job run db-restore
