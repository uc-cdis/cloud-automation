#!/bin/bash

if [ -z "$VPC_NAME" ]; then
    read -p "Enter your VPC name (only alphanumeric characters): " VPC_NAME
fi
creds_dir=$HOME/.creds/$VPC_NAME
cd tf_files
LOGIN_NODE=`grep -A20 "aws_eip.login" $creds_dir/terraform.tfstate | grep "public_ip" | head -1 | sed 's/[ \",]//g' | cut -d: -f2`

echo "Working with Login Node: $LOGIN_NODE"

OUTPUT_DIR=${VPC_NAME}_output
echo "Working with $OUTPUT_DIR"

# Destroy namespaces
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPC_NAME; export KUBECONFIG=kubeconfig; kubectl delete namespace --all; kubectl delete deployments --all; kubectl delete services --all"

# Destroy kube
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPC_NAME && http_proxy=http://cloud-proxy.internal.io:3128 https_proxy=http://cloud-proxy.internal.io:3128 no_proxy=.internal.io kube-aws destroy "

# Destroy terraform
../terraform init -backend-config=$creds_dir/terraform.tfvars
../terraform destroy -var-file=$creds_dir/tf_variables
