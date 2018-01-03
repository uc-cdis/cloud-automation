#!/bin/bash

if [ -z "$VPC_NAME" ]; then
    read -p "Enter your old VPC name (only alphanumeric characters): " VPC_NAME
fi
curdir=$(pwd)

cd tf_files/aws
# Make sure terraform is using correct configuration before pull.
../../terraform init -backend-config=$HOME/.creds/$VPC_NAME/terraform.tfvars
LOGIN_NODE=$(../../terraform state pull | grep -A20 "aws_eip.login" | grep "public_ip" | head -1 | sed 's/[ \",]//g' | cut -d: -f2)
echo "Working with Login Node: $LOGIN_NODE"

OUTPUT_DIR=${VPC_NAME}_output
echo "Working with $OUTPUT_DIR"
cd $OUTPUT_DIR

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $OUTPUT_DIR && python render_creds.py dump_creds" >old_vpc.variables

chmod +x old_vpc.variables
source old_vpc.variables
source $HOME/.creds/$VPC_NAME/tf_variables


# Clear variables we know definitely won't be reused
vpc_name=""
kube_bucket=""
db_password_fence=""
db_password_gdcapi=""
db_password_indexd=""
fence_snapshot=""
gdcapi_snapshot=""
indexd_snapshot=""

cd $curdir
