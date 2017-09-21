#!/bin/bash

if [ -z "$VPC_NAME" ]; then
    read -p "Enter your VPC name (only alphanumeric characters): " VPC_NAME
fi

cd tf_files/aws
# Make sure terraform is using correct configuration before pull.
../../terraform init -backend-config=$HOME/.creds/$VPC_NAME/terraform.tfvars
LOGIN_NODE=$(../../terraform state pull | grep -A20 "aws_eip.login" | grep "public_ip" | head -1 | sed 's/[ \",]//g' | cut -d: -f2)
echo "Working with Login Node: $LOGIN_NODE"

OUTPUT_DIR=${VPC_NAME}_output
echo "Working with $OUTPUT_DIR"

if [ ! -f $OUTPUT_DIR/cdis-devservices-secret.yml ]; then
    echo "Please provide cdis-devservices-secret.yml in tf_files/aws/$OUTPUT_DIR before proceeding"
    exit
fi

cp ../../bin/kube-aws $OUTPUT_DIR/.

set -e
scp -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" -r $OUTPUT_DIR ubuntu@kube.internal.io:/home/ubuntu/.
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $OUTPUT_DIR && chmod +x kube-up.sh && ./kube-up.sh"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $OUTPUT_DIR && mv cdis-devservices-secret.yml ../$VPC_NAME/. && chmod +x kube-services.sh && ./kube-services.sh"

set +e
