#!/bin/bash
#
# Deploy Atlas/WebAPI into existing commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

gen3 roll ohdsi-webapi
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-webapi/ohdsi-webapi-service.yaml"
gen3 roll ohdsi-atlas
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-service.yaml"
g3kubectl apply -f "${GEN3_HOME}/kube/services/ohdsi-atlas/ohdsi-atlas-service-elb.yaml"

cat <<EOM
The Atlas/WebAPI service has been deployed onto the k8s cluster.
EOM
