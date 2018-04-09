#!/bin/bash
#
# Initializes the Gen3 k8s cronjobs.
#

if ! kubectl get cronjob google-manage-keys > /dev/null 2>&1; then
   kubectl create -f "${G3AUTOHOME}/kube/services/jenkins/google-manage-keys-cronjob.yaml"
fi

if ! kubectl get cronjob google-manage-account-access > /dev/null 2>&1; then
   kubectl create -f "${G3AUTOHOME}/kube/services/jenkins/google-manage-account-access-cronjob.yaml"
fi