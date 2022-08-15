#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

export KUBECTL_VERSION=$(kubectl version 2>&1)

cd "${HOME}/Gen3Secrets/"

if [[ $KUBECTL_VERSION == 'error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"' ]]; then
    yq -yi '.users[0].user.exec.apiVersion = "client.authentication.k8s.io/v1beta1" | .users[0].user.exec.command = "aws" | .users[0].user.exec.args=[ "--region","us-east-1","eks","get-token","--cluster-name","oadc"]' kubeconfig
else
    echo "error not present- skipping"
fi