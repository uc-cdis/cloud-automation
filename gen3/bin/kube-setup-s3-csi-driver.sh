#!/bin/bash

####################################################################################################
# Script: kube-setup-s3-csi-driver.sh
#
# Description:
#   This script sets up the Mountpoint for Amazon S3 CSI driver in an EKS cluster.
#   It creates necessary IAM policies and roles.
#
# Usage:
#   gen3 kube-setup-s3-csi-driver [bucket_name]
#
####################################################################################################

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

account_id=$(aws sts get-caller-identity --query "Account" --output text)
vpc_name="$(gen3 api environment)"
namespace="$(gen3 db namespace)"
default_bucket_name_encrypted="gen3-db-backups-encrypted-${account_id}"
bucket_name=${1:-$default_bucket_name_encrypted}

cluster_arn=$(kubectl config current-context)
eks_cluster=$(echo "$cluster_arn" | awk -F'/' '{print $2}')

gen3_log_info "account_id: $account_id"
gen3_log_info "vpc_name: $vpc_name"
gen3_log_info "namespace: $namespace"
gen3_log_info "bucket_name: $bucket_name"
gen3_log_info "eks_cluster: $eks_cluster"

# Create policy for Mountpoint for Amazon S3 CSI driver
create_s3_csi_policy() {
  policy_name="AmazonS3CSIDriverPolicy-${eks_cluster}"
  policy_arn=$(aws iam list-policies --query "Policies[?PolicyName == '$policy_name'].[Arn]" --output text)
  if [ -z "$policy_arn" ]; then
    cat <<EOF > /tmp/s3-csi-policy-$$.json
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
                "arn:aws:s3:::${bucket_name}"
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
                "arn:aws:s3:::${bucket_name}/*"
            ]
        }
    ]
}
EOF
    policy_arn=$(aws iam create-policy --policy-name "$policy_name" --policy-document file:///tmp/s3-csi-policy-$$.json --query "Policy.Arn" --output text)
    rm -f /tmp/s3-csi-policy-$$.json
  fi
  gen3_log_info "Created or found policy with ARN: $policy_arn"
  echo $policy_arn
}

# Create the trust policy for Mountpoint for Amazon S3 CSI driver
create_s3_csi_trust_policy() {
  oidc_url=$(aws eks describe-cluster --name $eks_cluster --query 'cluster.identity.oidc.issuer' --output text | sed -e 's/^https:\/\///')
  trust_policy_file="/tmp/aws-s3-csi-driver-trust-policy-$$.json"
  cat <<EOF > ${trust_policy_file}
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
}

# Create the IAM role for Mountpoint for Amazon S3 CSI driver
create_s3_csi_role() {
  role_name="AmazonEKS_S3_CSI_DriverRole-${eks_cluster}"
  if ! aws iam get-role --role-name $role_name 2>/dev/null; then
    aws iam create-role --role-name $role_name --assume-role-policy-document file:///tmp/aws-s3-csi-driver-trust-policy-$$.json
    rm -f /tmp/aws-s3-csi-driver-trust-policy-$$.json
  fi
  gen3_log_info "Created or found role: $role_name"
  echo $role_name
}

# Attach the policies to the IAM role
attach_s3_csi_policies() {
  role_name=$1
  policy_arn=$2
  eks_policy_name="eks-s3-csi-policy-${eks_cluster}"
  gen3_log_info "Attaching S3 CSI policy with ARN: $policy_arn to role: $role_name"
  eks_policy_arn=$(aws iam list-policies --query "Policies[?PolicyName == '$eks_policy_name'].Arn" --output text)
  if [ -z "$eks_policy_arn" ]; then
    cat <<EOF > /tmp/eks-s3-csi-policy-$$.json
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
                "arn:aws:s3:::${bucket_name}",
                "arn:aws:s3:::${bucket_name}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:Encrypt",
                "kms:GenerateDataKey"
            ],
            "Resource": "*"
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
    eks_policy_arn=$(aws iam create-policy --policy-name "$eks_policy_name" --policy-document file:///tmp/eks-s3-csi-policy-$$.json --query "Policy.Arn" --output text)
    rm -f /tmp/eks-s3-csi-policy-$$.json
  fi
  aws iam attach-role-policy --role-name $role_name --policy-arn $policy_arn
  aws iam attach-role-policy --role-name $role_name --policy-arn $eks_policy_arn
}

# Create or update the CSI driver and its resources
setup_csi_driver() {
  create_s3_csi_policy
  policy_arn=$(aws iam list-policies --query "Policies[?PolicyName == 'AmazonS3CSIDriverPolicy-${eks_cluster}'].[Arn]" --output text)
  create_s3_csi_trust_policy
  create_s3_csi_role
  role_name="AmazonEKS_S3_CSI_DriverRole-${eks_cluster}"
  attach_s3_csi_policies $role_name $policy_arn

  # Install CSI driver
  gen3_log_info "eks cluster name: $eks_cluster"

  # Capture the output of the command and prevent it from exiting the script
  csi_driver_check=$(aws eks describe-addon --cluster-name $eks_cluster --addon-name aws-mountpoint-s3-csi-driver --query 'addon.addonName' --output text 2>&1 || true)

  if echo "$csi_driver_check" | grep -q "ResourceNotFoundException"; then
    gen3_log_info "CSI driver not found, installing..."
    aws eks create-addon --cluster-name $eks_cluster --addon-name aws-mountpoint-s3-csi-driver --service-account-role-arn arn:aws:iam::${account_id}:role/AmazonEKS_S3_CSI_DriverRole-${eks_cluster}
    csi_status="CREATING"
    retries=0
    while [ "$csi_status" != "ACTIVE" ] && [ $retries -lt 12 ]; do
      gen3_log_info "Waiting for CSI driver to become active... (attempt $((retries+1)))"
      sleep 10
      csi_status=$(aws eks describe-addon --cluster-name $eks_cluster --addon-name aws-mountpoint-s3-csi-driver --query 'addon.status' --output text || echo "CREATING")
      retries=$((retries+1))
    done
    if [ "$csi_status" == "ACTIVE" ]; then
      gen3_log_info "CSI driver successfully installed and active."
    else
      gen3_log_error "CSI driver installation failed or not active. Current status: $csi_status"
    fi
  elif echo "$csi_driver_check" | grep -q "aws-mountpoint-s3-csi-driver"; then
    gen3_log_info "CSI driver already exists, skipping installation."
  else
    gen3_log_info "Unexpected error occurred: $csi_driver_check"
    exit 1
  fi
}

setup_csi_driver
