#!/bin/bash

cd tf_files
LOGIN_NODE=`grep -A20 "aws_eip.login" terraform.tfstate | grep "public_ip" | head -1 | sed 's/[ \",]//g' | cut -d: -f2`

echo "Working with Login Node: $LOGIN_NODE"

OUTPUT_DIR=`ls -d *_output | head -1`
echo "Working with $OUTPUT_DIR"
VPCNAME=`echo $OUTPUT_DIR | cut -d_ -f1`

# Destroy namespaces
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete namespace --all"

# Destroy kube

ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && http_proxy=http://cloud-proxy.internal.io:3128 https_proxy=http://cloud-proxy.internal.io:3128 no_proxy=.internal.io kube-aws destroy "

# Destroy terraform

../terraform destroy -var-file=../../tf_variables
