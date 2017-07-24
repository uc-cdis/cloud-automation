#!/bin/bash

cd tf_files
LOGIN_NODE=`grep -A20 "aws_eip.login" terraform.tfstate | grep "public_ip" | head -1 | sed 's/[ \",]//g' | cut -d: -f2`

echo "Working with Login Node: $LOGIN_NODE"

OUTPUT_DIR=`ls -d *_output | head -1`
echo "Working with $OUTPUT_DIR"
VPCNAME=`echo $OUTPUT_DIR | cut -d_ -f1`

# Destroy services
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/portal/portal-deploy.yaml"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/userapi/userapi-deploy.yaml"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/indexd/indexd-deploy.yaml"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/gdcapi/gdcapi-deploy.yaml"

ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/userapi/userapi-service.yaml"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/portal/portal-service.yaml"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/indexd/indexd-service.yaml"
ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && kubectl --kubeconfig=kubeconfig delete -f services/gdcapi/gdcapi-service.yaml"

# Destroy kube

ssh -o "ProxyCommand ssh ubuntu@$LOGIN_NODE nc %h %p" ubuntu@kube.internal.io "cd $VPCNAME && http_proxy=http://cloud-proxy.internal.io:3128 https_proxy=http://cloud-proxy.internal.io:3128 no_proxy=.internal.io kube-aws destroy "

# Destroy terraform

../terraform destroy -var-file=../../tf_variables
