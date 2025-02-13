#!/bin/bash

####################################################################################################
# Script: gen3 rds-snapshot-export
#
# Description:
#   Automates exporting the latest RDS snapshot to an S3 bucket.
#   Supports creating CronJobs for periodic exports or triggering an immediate export.
#
# Options:
#   --cluster-name <name>      Name of the RDS cluster to export snapshots from (required)
#   --interval <days>          Interval in days for the export cron job (default: 30)
#   --immediate                Trigger an immediate export of the latest snapshot.
#
# Examples:
#   Setup a CronJob:
#     gen3 rds-snapshot-export --cluster-name prod-aurora-cluster --interval 30
#   Trigger an Immediate Export:
#     gen3 rds-snapshot-export --cluster-name prod-aurora-cluster --immediate
####################################################################################################

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#set -x
# Variables
account_id=$(aws sts get-caller-identity --query "Account" --output text)
environment=$(gen3 api environment)
region=$(gen3_aws_run aws configure get region || echo "us-east-1")
namespace=$(gen3 db namespace)
sa_name="rds-snapshot-export-sa"
default_bucket_name="gen3-db-backups-encrypted-${account_id}"
default_interval=30
bucket_name=""
cluster_name=""
export_mode="cron"

# Functions
help() {
  cat <<EOM
Usage:
  gen3 rds-snapshot-export [OPTIONS]

Options:
  --cluster-name <name>      Name of the RDS cluster to export snapshots from (required)
  --interval <days>          Interval in days for the export cron job (default: 30)
  --immediate                Trigger an immediate export of the latest snapshot.

Examples:
  Setup a CronJob:
    gen3 rds-snapshot-export --cluster-name prod-aurora-cluster --interval 30
  Trigger an Immediate Export:
    gen3 rds-snapshot-export --cluster-name prod-aurora-cluster --immediate
EOM
}

validate_environment() {
  if [[ -z "$namespace" || -z "$environment" || -z "$account_id" ]]; then
    echo "Error: Required environment variables are missing."
    echo "Namespace: $namespace, Environment: $environment, Account ID: $account_id"
    exit 1
  fi
}

create_service_account_and_role() {
    echo "Setting up service account and IAM role..."
    oidc_url=$(aws eks describe-cluster --name "$environment" --query 'cluster.identity.oidc.issuer' --output text | sed -e 's/^https:\/\///')
    role_name="rds-snapshot-export-role-${environment}"
    role_arn="arn:aws:iam::${account_id}:role/${role_name}"
    bucket_arn="arn:aws:s3:::${bucket_name}"
    policy_name="RDSExportPolicy-${environment}"

    # Create the trust policy for the role
    local trust_policy=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_policy.XXXXXX")
    cat > ${trust_policy} <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/${oidc_url}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${oidc_url}:aud": "sts.amazonaws.com",
          "${oidc_url}:sub": "system:serviceaccount:${namespace}:${sa_name}"
        }
      }
    }
  ]
}
EOF

    # Create or update the IAM role
    if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
        echo "Updating trust relationship for Kubernetes role..."
        aws iam update-assume-role-policy --role-name "$role_name" --policy-document "file://${trust_policy}"
    else
        echo "Creating Kubernetes IAM role..."
        aws iam create-role --role-name "$role_name" --assume-role-policy-document "file://${trust_policy}"
    fi

    # Create or update the policy
    existing_policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${policy_name}'].Arn" --output text)
    if [[ -z "$existing_policy_arn" ]]; then
        policy_arn=$(aws iam create-policy --policy-name "$policy_name" --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "s3:PutObject*",
                "s3:GetObject*",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "sts:GetCallerIdentity"
              ],
              "Resource": [
                "'"$bucket_arn"'",
                "'"$bucket_arn"'/*"
              ]
            },
            {
              "Effect": "Allow",
              "Action": [
                "rds:DescribeDBClusterSnapshots",
                "rds:StartExportTask",
                "rds:DescribeDBClusters",
                "rds:DescribeExportTasks"
              ],
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": "iam:PassRole",
              "Resource": "arn:aws:iam::'"$account_id"':role/rds-s3-export-role"
            }
          ]
        }' --query Policy.Arn --output text)
    else
        policy_arn="$existing_policy_arn"
    fi

    if [[ -z "$policy_arn" || "$policy_arn" == "None" ]]; then
        echo "Error: Failed to create or retrieve policy ARN for $policy_name"
        exit 1
    fi

    # Attach the policy to the role
    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"

    # Create the Kubernetes service account if it doesn't exist
    if ! kubectl get serviceaccount -n "$namespace" "$sa_name" >/dev/null 2>&1; then
        kubectl create serviceaccount -n "$namespace" "$sa_name"
    fi

    # Annotate the service account with the IAM role ARN
    kubectl annotate serviceaccount -n "$namespace" "$sa_name" eks.amazonaws.com/role-arn="$role_arn" --overwrite
}

create_rds_assume_role() {
  echo "Setting up Amazon RDS export role..."
  rds_role_name="rds-s3-export-role-${environment}"
  bucket_arn="arn:aws:s3:::${bucket_name}"
  rds_policy_name="RDSExportS3Policy-${environment}"

  # Create the trust policy for the RDS role
  local rds_trust_policy=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_policy.XXXXXX")
  cat > $rds_trust_policy <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "export.rds.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  # Create or update the RDS role
  if aws iam get-role --role-name "$rds_role_name" >/dev/null 2>&1; then
      echo "Updating trust relationship for RDS role..."
      aws iam update-assume-role-policy --role-name "$rds_role_name" --policy-document "file://$rds_trust_policy"
  else
      echo "Creating RDS IAM role..."
      aws iam create-role --role-name "$rds_role_name" --assume-role-policy-document "file://$rds_trust_policy"
  fi

  # Check or create policy
  rds_policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${rds_policy_name}'].Arn" --output text)
  if [[ -z "$rds_policy_arn" || "$rds_policy_arn" == "None" ]]; then
      echo "Creating RDS S3 policy $rds_policy_name..."
      rds_policy_arn=$(aws iam create-policy --policy-name "$rds_policy_name" --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "s3:PutObject*",
              "s3:GetObject*",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:GetBucketLocation"
            ],
            "Resource": [
              "'"$bucket_arn"'",
              "'"$bucket_arn"'/*"
            ]
          },
          {
            "Effect": "Allow",
            "Action": "kms:GenerateDataKey",
            "Resource": "*"
          }
        ]
      }' --query Policy.Arn --output text)

      if [[ -z "$rds_policy_arn" || "$rds_policy_arn" == "None" ]]; then
          echo "Error: Failed to create policy $rds_policy_name"
          exit 1
      fi
  else
      echo "Policy $rds_policy_name already exists with ARN: $rds_policy_arn"
  fi

  echo "Attaching policy to role $rds_role_name..."
  aws iam attach-role-policy --role-name "$rds_role_name" --policy-arn "$rds_policy_arn"
}

trigger_job() {
  echo "Triggering RDS Snapshot Export Job..."
  gen3 job run rds-snapshot-export CLUSTER_NAME="$cluster_name" BUCKET_NAME="$bucket_name"
}

create_cron_job() {
  cron_file="$XDG_RUNTIME_DIR/rds-snapshot-export-cron.yaml"

  # Check if a cron job already exists
  if kubectl get cronjob -n "$namespace" "rds-snapshot-export-$cluster_name" >/dev/null 2>&1; then
    echo "CronJob rds-snapshot-export-$cluster_name already exists. Skipping creation."
    return
  fi

  cat <<EOF > "$cron_file"
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rds-snapshot-export-$cluster_name
spec:
  schedule: "0 0 */${interval} * *"
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: rds-snapshot-export-sa
          containers:
          - name: rds-snapshot-export
            image: quay.io/cdis/awshelper:master
            command:
            - /bin/bash
            - -c
            - |
              gen3 job run rds-snapshot-export CLUSTER_NAME=$(echo $cluster_name) BUCKET_NAME=$(echo $bucket_name)
          restartPolicy: Never
EOF

  kubectl apply -f "$cron_file"
}

# Parse Command-Line Arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --cluster-name)
      cluster_name="$2"
      shift
      shift
      ;;
    --interval)
      interval="$2"
      export_mode="cron"
      shift
      shift
      ;;
    --immediate)
      export_mode="immediate"
      shift
      ;;
    *)
      help
      exit 1
      ;;
  esac
done

# Ensure interval is set to default if not provided
if [[ -z "$interval" ]]; then
  interval="$default_interval"
fi

# Validations
if [[ -z "$cluster_name" ]]; then
  gen3_log_err "Error: --cluster-name is required"
  help
  exit 1
fi

# Set Defaults
bucket_name="${default_bucket_name}"

# Execution
validate_environment
create_service_account_and_role
create_rds_assume_role

if [[ "$export_mode" == "immediate" ]]; then
  trigger_job
else
  create_cron_job
fi
