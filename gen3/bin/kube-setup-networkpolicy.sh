#!/bin/bash
#
# Apply network policy to the core services of the commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


serverVersion="$(g3kubectl version server -o json | jq -r '.serverVersion.major + "." + .serverVersion.minor' | head -c4).0"
echo "K8s server version is $serverVersion"
if ! semver_ge "$serverVersion" "1.8.0"; then
  echo "K8s server version $serverVersion does not yet support network policy"
  exit 0
fi
if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping network policy manipulation: $JENKINS_HOME"
  exit 0
fi

name2IP() {
  local name
  local ip
  name="$1"
  ip="$name"
  if [[ ! "$name" =~ ^[0-9\.\:]+$ ]]; then
    ip=$(dig "$name" +short)
  fi
  echo "$ip"
}

#......................................

notebookNamespace="(gen3 jupyter j-namespace)"

# apply base policies in both the commons namespace and the jupyter/user namespace
for name in "${GEN3_HOME}/kube/services/netpolicy/base/"*.yaml; do
  echo "... applying $name"
  g3kubectl apply -f "$name"
  (yq -r . < "$name") | jq -r --arg namespace "$notebookNamespace" '.metadata.namespace=$namespace' | g3kubectl apply -f -
done

# apply gen3 generic policies in commons namespace
for name in "${GEN3_HOME}/kube/services/netpolicy/gen3/"*.yaml; do
  g3kubectl apply -f "$name"
done

# apply service-specific policies
for name in "${GEN3_HOME}/kube/services/netpolicy/gen3/services/"*.yaml; do
  (g3k_kv_filter "$name" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" NOTEBOOK_NAMESPACE "namespace: $notebookNamespace" | g3kubectl apply -f -) || true
done

# apply procedurally-generated policies
# external internet access in both commons and user namespaces
gen3 netpolicy external | g3kubectl apply -f
gen3 netpolicy external | jq -r --arg namespace "$notebookNamespace" '.spec.podSelector={} | .metadata.namespace=$namespace' | g3kubectl apply -f
# s3 access
gen3 netpolicy s3 | g3kubectl apply -f
# db access
for serviceName in $(gen3 db services); do
  gen3 netpolicy db "$serviceName" | g3kubectl apply -f -
done
