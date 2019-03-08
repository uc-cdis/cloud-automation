#!/bin/bash
#
# Deploy manifestservice into existing commons
# This is an optional service that's not part of gen3 core services
# It only needs to be deployed to commons that have Export to Workspace functionality


# TODO: s3 creds are figured out in here i tihnk right?


source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

# deploy manifest-service
gen3 roll manifestservice
g3kubectl apply -f "${GEN3_HOME}/kube/services/manifestservice/manifestservice-service.yaml"

cat <<EOM
The manifest service has been deployed onto the k8s cluster.
EOM
