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

if [ ! -f $OUTPUT_DIR/cdis-devservices-secret.yml ]; then
	echo "Please provide cdis-devservices-secret.yml in $OUTPUT_DIR before proceeding"
	exit
fi

cp ../bin/kube-aws $OUTPUT_DIR/.

set -e
scp -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" -r $OUTPUT_DIR ubuntu@kube.internal.io:/home/ubuntu/.
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $OUTPUT_DIR && chmod +x kube-up.sh && ./kube-up.sh"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $OUTPUT_DIR && mv cdis-devservices-secret.yml ../$VPC_NAME/. && chmod +x kube-services.sh && ./kube-services.sh"

read -n 1 -p "Set up kubenode.internal.io in your route53 before proceeding, ok? " DNSSETUP

scp -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" $OUTPUT_DIR/revproxy-setup.sh ubuntu@revproxy.internal.io:/home/ubuntu/.
scp -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" $OUTPUT_DIR/proxy.conf ubuntu@revproxy.internal.io:/home/ubuntu/.
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@revproxy.internal.io "chmod +x revproxy-setup.sh && ./revproxy-setup.sh"
set +e
