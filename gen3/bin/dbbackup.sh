#!/bin/bash

####################################################################################################
# Script: dbbackup.sh
#
# Description:
#   This script facilitates the management of database backups within the gen3 environment. It is
#   equipped to establish policies, service accounts, roles, and S3 buckets. Depending on the
#   command provided, it will either initiate a database dump, perform a restore, migrate to Aurora,
#   or copy to Aurora.
#
# Usage:
#   gen3 dbbackup [dump|restore|va-dump|create-sa|migrate-to-aurora|copy-to-aurora <source_namespace>]
#
#   dump           - Initiates a database dump, creating the essential AWS resources if they are absent.
#                    The dump operation is intended to be executed from the namespace/commons that requires
#                    the backup.
#   restore        - Initiates a database restore, creating the essential AWS resources if they are absent.
#                    The restore operation is meant to be executed in the target namespace, where the backup
#                    needs to be restored.
#   va-dump        - Runs a va-testing DB dump.
#   create-sa      - Creates the necessary service account and roles for DB copy.
#   migrate-to-aurora - Triggers a service account creation and a job to migrate a Gen3 commons to an AWS RDS Aurora instance.
#   copy-to-aurora    - Triggers a service account creation and a job to copy the databases Indexd, Sheepdog & Metadata to new databases within an RDS Aurora cluster.
#
#
####################################################################################################

# Exit on error
#set -e

# Print commands before executing
#set -x

#trap 'echo "Error at Line $LINENO"' ERR

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

policy_name="bucket_reader_writer_gen3_db_backup"
account_id=$(aws sts get-caller-identity --query "Account" --output text)
vpc_name="$(gen3 api environment)"
namespace="$(gen3 db namespace)"
sa_name="dbbackup-sa"
bucket_name="gen3-db-backups-${account_id}"

gen3_log_info "policy_name: $policy_name"
gen3_log_info "account_id: $account_id"
gen3_log_info "vpc_name: $vpc_name"
gen3_log_info "namespace: $namespace"
gen3_log_info "sa_name: $sa_name"
gen3_log_info "bucket_name: $bucket_name"

# Create an S3 access policy if it doesn't exist
create_policy() {
  # Check if policy exists
  if ! aws iam list-policies --query "Policies[?PolicyName == '$policy_name'] | [0].Arn" --output text | grep -q "arn:aws:iam"; then
    # Create the S3 access policy - policy document
    access_policy=$(cat <<-EOM
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
    policy_arn=$(aws iam create-policy --policy-name "$policy_name" --policy-document "$access_policy" --query "Policy.Arn" --output text)
    gen3_log_info "policy_arn: $policy_arn"
  else
    gen3_log_info "Policy $policy_name already exists, skipping policy creation."
    policy_arn=$(aws iam list-policies --query "Policies[?PolicyName == '$policy_name'] | [0].Arn" --output text | grep "arn:aws:iam" | head -n 1)
    gen3_log_info "policy_arn: $policy_arn"
  fi
}

# Create or update the Service Account and its corresponding IAM Role
create_service_account_and_role() {
    cluster_arn=$(kubectl config current-context)
    eks_cluster=$(echo "$cluster_arn" | awk -F'/' '{print $2}')
    oidc_url=$(aws eks describe-cluster --name $eks_cluster --query 'cluster.identity.oidc.issuer' --output text | sed -e 's/^https:\/\///')
    role_name="${vpc_name}-${namespace}-${sa_name}-role"
    role_arn="arn:aws:iam::${account_id}:role/${role_name}"
    local trust_policy=$(mktemp -p "$XDG_RUNTIME_DIR" "tmp_policy.XXXXXX")
    gen3_log_info "trust_policy: $trust_policy"
    gen3_log_info "eks_cluster: $eks_cluster"
    gen3_log_info "oidc_url: $oidc_url"
    gen3_log_info "role_name: $role_name"

  cat > ${trust_policy} <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
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

  echo ${trust_policy}
  gen3_log_info "Exiting create_assume_role_policy"

    # Create or Update IAM Role
    gen3_log_info " Create or Update IAM Role"
    if aws iam get-role --role-name $role_name 2>&1; then
        gen3_log_info "Updating existing role: $role_name"
        aws iam update-assume-role-policy --role-name $role_name --policy-document "file://$trust_policy"
    else
        gen3_log_info "Creating new role: $role_name"
        aws iam create-role --role-name $role_name --assume-role-policy-document "file://$trust_policy"
    fi

    # Attach the policy to the IAM role
    aws iam attach-role-policy --role-name $role_name --policy-arn $policy_arn

    # Create the Kubernetes service account if it doesn't exist
    if ! kubectl get serviceaccount -n $namespace $sa_name 2>&1; then
        kubectl create serviceaccount -n $namespace $sa_name
    fi
        # Annotate the KSA with the IAM role ARN
    gen3_log_info "Annotating Service Account with IAM role ARN"
    kubectl annotate serviceaccount -n ${namespace} ${sa_name} eks.amazonaws.com/role-arn=${role_arn} --overwrite

}

# Create an S3 bucket if it doesn't exist
create_s3_bucket() {
  # Check if bucket already exists
  if aws s3 ls "s3://$bucket_name" 2>&1 | grep -q 'NoSuchBucket'; then
      gen3_log_info "Bucket does not exist, creating..."
      aws s3 mb "s3://$bucket_name"
  else
      gen3_log_info "Bucket $bucket_name already exists, skipping bucket creation."
  fi
}

# Function to trigger the database backup job
db_dump() {
    gen3 job run psql-db-prep-dump
}

# Function to trigger the database backup restore job
db_restore() {
    gen3 job run psql-db-prep-restore
}

va_testing_db_dump() {
  gen3 job run psql-db-dump-va-testing
}

# Function to create the psql-db-copy service account and roles
create_db_copy_service_account() {
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: psql-db-copy-sa

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psql-db-copy-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: psql-db-copy-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psql-db-copy-role
subjects:
- kind: ServiceAccount
  name: psql-db-copy-sa
  namespace: ${namespace}
EOF
}

# Function to run the Aurora migration job
migrate_to_aurora() {
    create_db_copy_service_account
    sleep 30
    gen3 job run psql-db-aurora-migration
}

# Function to run the Aurora copy job
copy_to_aurora() {
    create_db_copy_service_account
    sleep 30
    gen3 job run psql-db-copy-aurora SOURCE_NAMESPACE "$1"
}

# main function to determine whether dump, restore, or create service account
main() {
    case "$1" in
        dump)
            gen3_log_info "Triggering database dump..."
            create_policy
            create_service_account_and_role
            create_s3_bucket
            db_dump
            ;;
        restore)
            gen3_log_info "Triggering database restore..."
            create_policy
            create_service_account_and_role
            create_s3_bucket
            db_restore
            ;;
        va-dump)
            gen3_log_info "Running a va-testing DB dump..."
            create_policy
            create_service_account_and_role
            create_s3_bucket
            va_testing_db_dump
            ;;
        create-sa)
            gen3_log_info "Creating service account for DB copy..."
            create_db_copy_service_account
            ;;
        migrate-to-aurora)
            gen3_log_info "Migrating Gen3 commons to Aurora..."
            migrate_to_aurora
            ;;
        copy-to-aurora)
            if [ -z "$2" ]; then
                echo "Usage: $0 copy-to-aurora <source_namespace>"
                exit 1
            fi
            gen3_log_info "Copying databases within Aurora..."
            copy_to_aurora "$2"
            ;;
        *)
            echo "Invalid command. Usage: gen3 dbbackup [dump|restore|va-dump|create-sa|migrate-to-aurora|copy-to-aurora <source_namespace>]"
            return 1
            ;;
    esac
}

main "$@"
