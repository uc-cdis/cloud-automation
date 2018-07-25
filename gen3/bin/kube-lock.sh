#!/bin/bash
#
# Little helper derives terraform and k8s configuration
# from kubernetes secrets if possible.  
# Generates
#    $XDG_RUNTIME_DIR/kube-extract-config/creds.json, config.tfvars, and 00configmap.yaml
# Requries g3kubectl to be on the path and configured.
#