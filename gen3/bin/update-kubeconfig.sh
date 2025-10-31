#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

cd "${HOME}/Gen3Secrets/"

aws_version="0.0.0"
if aws --version 2>&1 > /dev/null; then
    aws_version="$(aws --version | awk '{ print $1 }' | awk -F / '{ print $2 }')"
fi
if ! semver_ge "$aws_version" "2.7.0"; then
    gen3_log_err "awscli is on version $aws_version. Please update to latest version before running this command again. \nHint: 'gen3 kube-setup-workvm' can take care of that for you."
    exit 0
fi 

namespace=$(gen3 api namespace)

if [ ! -z "$KUBECONFIG" ]; then
    if [ -f "$FILE" ]; then
        gen3_log_info "Backing up existing kubeconfig located at $KUBECONFIG"
        mv "$KUBECONFIG" "$KUBECONFIG.backup"
    fi
else
    gen3_log_warn "KUBECONFIG env var is not set. Cannot take backup of existing kubeconfig."
fi 

gen3_log_info "Updating kubeconfig by running 'aws eks update-kubeconfig --name $vpc_name'"
aws eks update-kubeconfig --name $vpc_name

gen3_log_info "Setting namespace to $namespace. ('kubectl config set-context --current --namespace=$namespace')"
kubectl config set-context --current --namespace=$namespace
