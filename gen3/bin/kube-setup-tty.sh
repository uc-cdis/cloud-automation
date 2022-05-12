#!/bin/bash
#
# Deploy workspace-token-service into existing commons,
# this is an optional service that's not part of gen3 core services

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ---------------------

saName="tty-sa"

if ! g3kubectl get sa "$saName" > /dev/null 2>&1; then
  g3kubectl create sa "$saName" || exit 1
fi

role="$(cat - <<EOM
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tty-gen3-role
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "pods/log", "configmaps", "deployments", "jobs", "cronjobs", "replicasets", "services"]
  verbs: ["*"]
  #verbs: ["get", "list", "create", "update", "patch", "delete"] # You can also use ["*"]
EOM
)"

g3kubectl apply -f - <<< "$role"
g3kubectl -n "$(gen3 jupyter j-namespace)" apply -f - <<< "$role"

roleBinding="$(cat - <<EOM
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tty-gen3-binding
subjects:
- kind: ServiceAccount
  name: tty-sa
  namespace: $(gen3 api namespace)
roleRef:
  kind: Role
  name: tty-gen3-role
  apiGroup: rbac.authorization.k8s.io
EOM
)"

g3kubectl apply -f - <<< "$roleBinding"
g3kubectl -n "$(gen3 jupyter j-namespace)" apply -f - <<< "$roleBinding"

g3kubectl apply -f "${GEN3_HOME}/kube/services/tty/tty-service.yaml"  
gen3 roll tty

gen3_log_info "The tty service has been deployed onto the k8s cluster."
