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
#   gen3 dbbackup [dump|restore|va-dump|create-sa|migrate-to-aurora|copy-to-aurora|encrypt|setup-cron <source_namespace>]
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
#   copy-to-aurora    - Triggers a service account creation and a job to copy the databases Indexd, Sheepdog & Metadata to new databases within an RDS Aurora cluster. The source_namespace must be provided. The job should be run at the destination, not at the source.
#   encrypt        - Perform encrypted backup.
#   setup-cron     - Set up a cronjob for encrypted backup.
#
####################################################################################################



source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

policy_name="bucket_reader_writer_gen3_db_backup"
account_id=$(aws sts get-caller-identity --query "Account" --output text)
vpc_name="$(gen3 api environment)"
namespace="$(gen3 db namespace)"
sa_name="dbbackup-sa"
bucket_name="gen3-db-backups-${account_id}"
bucket_name_encrypted="gen3-db-backups-encrypted-${account_id}"
kms_key_alias="alias/gen3-db-backups-kms-key"


gen3_log_info "account_id: $account_id"
gen3_log_info "vpc_name: $vpc_name"
gen3_log_info "namespace: $namespace"
gen3_log_info "sa_name: $sa_name"
gen3_log_info "bucket_name: $bucket_name"
gen3_log_info "bucket_name_encrypted: $bucket_name_encrypted"
gen3_log_info "kms_key_alias: $kms_key_alias"

# Create or get the KMS key
create_or_get_kms_key() {
  kms_key_id=$(aws kms list-aliases --query "Aliases[?AliasName=='$kms_key_alias'].TargetKeyId" --output text)
  if [ -z "$kms_key_id" ]; then
    gen3_log_info "Creating new KMS key with alias $kms_key_alias"
    kms_key_id=$(aws kms create-key --query "KeyMetadata.KeyId" --output text)
    aws kms create-alias --alias-name $kms_key_alias --target-key-id $kms_key_id
  else
    gen3_log_info "KMS key with alias $kms_key_alias already exists"
  fi
  kms_key_arn=$(aws kms describe-key --key-id $kms_key_id --query "KeyMetadata.Arn" --output text)
  gen3_log_info "KMS Key ARN: $kms_key_arn"
}

# Create an S3 access policy if it doesn't exist
create_policy() {
  if ! aws iam list-policies --query "Policies[?PolicyName == '$policy_name'] | [0].Arn" --output text | grep -q "arn:aws:iam"; then
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
        "arn:aws:s3:::gen3-db-backups-*",
        "arn:aws:s3:::gen3-db-backups-encrypted-*"
      ]
    }
  ]
}
EOM
    )
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
    gen3_log_info "Create or Update IAM Role"
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

# Create an S3 bucket with SSE-KMS if it doesn't exist
create_s3_bucket() {
  local bucket_name=$1
  local kms_key_arn=$2
  # Check if bucket already exists
  if aws s3 ls "s3://$bucket_name" 2>&1 | grep -q 'NoSuchBucket'; then
      gen3_log_info "Bucket does not exist, creating..."
      aws s3 mb "s3://$bucket_name"
      # Enable SSE-KMS encryption on the bucket
      aws s3api put-bucket-encryption --bucket $bucket_name --server-side-encryption-configuration '{
        "Rules": [{
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "aws:kms",
            "KMSMasterKeyID": "'"$kms_key_arn"'"
          }
        }]
      }'
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
  namespace: ${namespace}
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

# Function to perform encrypted backup
encrypt_backup() {
    gen3 job run psql-db-backup-encrypt
}

# Function to set up cronjob for encrypted backup
setup_cronjob() {
    gen3 job cron psql-db-backup-encrypt "15 7 * * *"
}

# Create policy for Mountpoint for Amazon S3 CSI driver
create_s3_csi_policy() {
  policy_name="AmazonS3CSIDriverPolicy"
  gen3_log_info "Checking if policy $policy_name exists..."
  policy_arn=$(aws iam list-policies --query "Policies[?PolicyName == '$policy_name'] | [0].Arn" --output text)
  gen3_log_info "Policy ARN retrieved: $policy_arn"
  if [ -z "$policy_arn" ] || [ "$policy_arn" == "None" ]; then
    gen3_log_info "Policy $policy_name does not exist. Creating it..."
    cat <<EOF > /tmp/s3-csi-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "MountpointFullBucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${bucket_name_encrypted}"
            ]
        },
        {
            "Sid": "MountpointFullObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${bucket_name_encrypted}/*"
            ]
        }
    ]
}
EOF
    policy_arn=$(aws iam create-policy --policy-name "$policy_name" --policy-document file:///tmp/s3-csi-policy.json --query "Policy.Arn" --output text)
    gen3_log_info "Created S3 CSI policy with ARN: $policy_arn"
  else
    gen3_log_info "S3 CSI policy already exists with ARN: $policy_arn"
  fi
  echo $policy_arn
}

# Create the trust policy for Mountpoint for Amazon S3 CSI driver
create_s3_csi_trust_policy() {
  oidc_url=$(aws eks describe-cluster --name $vpc_name --query 'cluster.identity.oidc.issuer' --output text | sed -e 's/^https:\/\///')
  cat <<EOF > /tmp/aws-s3-csi-driver-trust-policy.json
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
                "StringLike": {
                    "${oidc_url}:aud": "sts.amazonaws.com",
                    "${oidc_url}:sub": "system:serviceaccount:*:s3-csi-*"
                }
            }
        }
    ]
}
EOF
  gen3_log_info "Created trust policy for S3 CSI driver: /tmp/aws-s3-csi-driver-trust-policy.json"
}

# Create the IAM role for Mountpoint for Amazon S3 CSI driver
create_s3_csi_role() {
  role_name="AmazonEKS_S3_CSI_DriverRole"
  gen3_log_info "Checking if role $role_name exists..."
  if ! aws iam get-role --role-name $role_name 2>/dev/null; then
    gen3_log_info "Creating IAM role for S3 CSI driver with the following command:"
    gen3_log_info "aws iam create-role --role-name $role_name --assume-role-policy-document file:///tmp/aws-s3-csi-driver-trust-policy.json"
    aws iam create-role --role-name $role_name --assume-role-policy-document file:///tmp/aws-s3-csi-driver-trust-policy.json
    gen3_log_info "Created IAM role: $role_name"
  else
    gen3_log_info "IAM role already exists: $role_name"
  fi
  echo $role_name
}

# Attach the policies to the IAM role
attach_s3_csi_policies() {
  role_name=$1
  policy_arn=$2
  gen3_log_info "Attaching S3 CSI policy with ARN: $policy_arn to role: $role_name"
  eks_policy_name="eks-s3-csi-policy"
  eks_policy_arn=$(aws iam list-policies --query "Policies[?PolicyName == '$eks_policy_name'].Arn" --output text)
  gen3_log_info "EKS policy ARN retrieved: $eks_policy_arn"
  if [ -z "$eks_policy_arn" ] || [ "$eks_policy_arn" == "None" ]; then
    gen3_log_info "EKS policy $eks_policy_name does not exist. Creating it..."
    cat <<EOF > /tmp/eks-s3-csi-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${bucket_name_encrypted}",
                "arn:aws:s3:::${bucket_name_encrypted}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:Encrypt",
                "kms:GenerateDataKey"
            ],
            "Resource": "${kms_key_arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    eks_policy_arn=$(aws iam create-policy --policy-name "$eks_policy_name" --policy-document file:///tmp/eks-s3-csi-policy.json --query "Policy.Arn" --output text)
    gen3_log_info "Created EKS policy with ARN: $eks_policy_arn"
  else
    gen3_log_info "EKS policy already exists with ARN: $eks_policy_arn"
  fi

  if [ -z "$policy_arn" ] || [ -z "$eks_policy_arn" ]; then
    gen3_log_err "One or both policy ARNs are invalid: S3 CSI policy ARN: $policy_arn, EKS policy ARN: $eks_policy_arn"
    exit 1
  fi

  gen3_log_info "Attaching policies to role: $role_name"
  aws iam attach-role-policy --role-name $role_name --policy-arn $policy_arn
  aws iam attach-role-policy --role-name $role_name --policy-arn $eks_policy_arn
}

# Create or update the CSI driver and its resources
setup_csi_driver() {
  create_or_get_kms_key
  gen3_log_info "KMS Key ARN: $kms_key_arn"
  
  policy_arn=$(create_s3_csi_policy)
  create_s3_csi_trust_policy
  role_name=$(create_s3_csi_role)
  attach_s3_csi_policies $role_name $policy_arn

  if ! kubectl get serviceaccount -n ${namespace} dbencrypt-sa 2>&1; then
    gen3_log_info "Creating service account for S3 CSI driver..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dbencrypt-sa
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dbencrypt-role
rules:
- apiGroups: [""]
  resources: ["secrets", "pods", "pods/exec", "services", "endpoints", "persistentvolumeclaims", "persistentvolumes", "configmaps"]
  verbs: ["get", "watch", "list", "create", "delete", "patch", "update"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "watch", "list", "create", "delete", "patch", "update"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets"]
  verbs: ["get", "watch", "list", "create", "delete", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dbencrypt-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dbencrypt-role
subjects:
- kind: ServiceAccount
  name: dbencrypt-sa
  namespace: ${namespace}
EOF
  fi

# Install CSI driver
gen3_log_info "eks cluster name: $eks_cluster"
aws eks create-addon --cluster-name $eks_cluster --addon-name aws-mountpoint-s3-csi-driver --service-account-role-arn arn:aws:iam::${account_id}:role/AmazonEKS_S3_CSI_DriverRole

# Check CSI driver installation status
csi_status=$(aws eks describe-addon --cluster-name $eks_cluster --addon-name aws-mountpoint-s3-csi-driver --query 'addon.status' --output text)
if [ "$csi_status" == "ACTIVE" ]; then
  gen3_log_info "CSI driver successfully installed and active."
else
  gen3_log_error "CSI driver installation failed or not active. Current status: $csi_status"
fi

  if ! kubectl get pv s3-pv-db-backups 2>&1; then
    gen3_log_info "Creating Persistent Volume and Persistent Volume Claim..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv-db-backups
spec:
  capacity:
    storage: 120Gi
  accessModes:
    - ReadWriteMany
  mountOptions:
    - allow-delete
    - allow-other
    - uid=1000
    - gid=1000
    - region us-east-1
    - sse aws:kms
    - sse-kms-key-id ${kms_key_arn}
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-db-backups-volume
    volumeAttributes:
      bucketName: ${bucket_name_encrypted}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc-db-backups
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 120Gi
  volumeName: s3-pv-db-backups
EOF
  fi
}

# Check prerequisites for encrypted backup and cronjob
check_prerequisites() {
    create_or_get_kms_key
    create_s3_bucket $bucket_name $kms_key_arn
    create_s3_bucket $bucket_name_encrypted $kms_key_arn
    setup_csi_driver
}

# main function to determine whether dump, restore, create service account, encrypt backup, or setup cronjob
main() {
    case "$1" in
        dump)
            gen3_log_info "Triggering database dump..."
            create_policy
            create_service_account_and_role
            create_or_get_kms_key
            create_s3_bucket $bucket_name $kms_key_arn
            db_dump
            ;;
        restore)
            gen3_log_info "Triggering database restore..."
            create_policy
            create_service_account_and_role
            create_or_get_kms_key
            create_s3_bucket $bucket_name $kms_key_arn
            db_restore
            ;;
        va-dump)
            gen3_log_info "Running a va-testing DB dump..."
            create_policy
            create_service_account_and_role
            create_or_get_kms_key
            create_s3_bucket $bucket_name $kms_key_arn
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
        encrypt)
            gen3_log_info "Performing encrypted backup..."
            check_prerequisites
            encrypt_backup
            ;;
        setup-cron)
            gen3_log_info "Setting up cronjob for encrypted backup..."
            check_prerequisites
            setup_cronjob
            ;;
        *)
            echo "Invalid command. Usage: gen3 dbbackup [dump|restore|va-dump|create-sa|migrate-to-aurora|copy-to-aurora|encrypt|setup-cron <source_namespace>]"
            return 1
            ;;
    esac
}

main "$@"
