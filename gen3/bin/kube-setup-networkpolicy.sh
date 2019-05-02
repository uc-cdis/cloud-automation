#!/bin/bash
#
# Apply network policy to the core services of the commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


serverVersion="$(g3kubectl version server -o json | jq -r '.serverVersion.major + "." + .serverVersion.minor' | head -c4).0"
if ! semver_ge "$serverVersion" "1.8.0"; then
  gen3_log_info "kube-setup-netpolciy" "K8s server version $serverVersion does not yet support network policy"
  exit 0
fi
if [[ -n "$JENKINS_HOME" ]]; then
  gen3_log_info "kube-setup-netpolciy" "Jenkins skipping network policy manipulation: $JENKINS_HOME"
  exit 0
fi

# lib -------------------------

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


#
# Deploy network policies that accomodate the
# gen3.io/network/ingress ACL included in gen3 deployments
#
# @param name of the service
#
apply_service() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "kube-setup-networkpolicy" "apply_service service not specified"
    return 1
  fi
  local name
  name="$1"
  shift
  local yamlPath
  if yamlPath="$(gen3 gitops rollpath "$name" 2> /dev/null)"; then
    if accessList="$(gen3 gitops filter "$yamlPath" | yq -e -r '.metadata.annotations["gen3.io/network/ingress"]')"; then
      accessList="${accessList//,/ }"
      gen3_log_info "networkpolicy - $name accessible by: ${accessList}"
      gen3 netpolicy ingressTo $name $accessList | g3kubectl apply -f -
      gen3 netpolicy egressTo $name $accessList | g3kubectl apply -f -
    else
      gen3_log_info "networkpolicy - $name not accessible"
      # delete previously generated policies if they exist
      g3kubectl delete networkpolicy "networkpolicy-ingress-to-$name" > /dev/null 2>&1
      g3kubectl delete networkpolicy "networkpolicy-egress-to-$name" > /dev/null 2>&1
    fi
  else
    gen3_log_info "kube_setup_networkpolicy" "failed to retrieve path for service ${name}: $yamlPath"
  fi
}


apply_gen3() {
  local name

  # apply base policies in both the commons namespace and the jupyter/user namespace
  for name in "${GEN3_HOME}/kube/services/netpolicy/base/"*.yaml; do
    g3kubectl apply -f "$name"
  done

  # apply gen3 generic policies in commons namespace
  for name in "${GEN3_HOME}/kube/services/netpolicy/gen3/"*.yaml; do
    g3kubectl apply -f "$name"
  done

  # apply service-specific policies
  for name in "${GEN3_HOME}/kube/services/netpolicy/gen3/services/"*.yaml; do
    g3kubectl apply -f "$name" || true
  done

  # apply procedurally-generated policies
  # external internet access in both commons and user namespaces
  gen3 netpolicy external | g3kubectl apply -f -
  # s3 access
  gen3 netpolicy s3 | g3kubectl apply -f -

  local serviceName
  # db access
  for serviceName in $(gen3 db services); do
    gen3 netpolicy db "$serviceName" | g3kubectl apply -f -
    gen3 netpolicy bydb "$serviceName" | g3kubectl apply -f -
  done

  #
  # apply ingress/egress rolls from gen3.io/network annotations
  # in the services refrenced by the manifest
  #
  g3k_manifest_lookup .versions | jq -r '. | keys | .[]' | while read -r name; do
    apply_service "$name"
  done

}


#
# Apply policy rules to the jupyter/user namespaces
#
apply_jupyter() {
  local notebookNamespace
  local name
  notebookNamespace="(gen3 jupyter j-namespace)"

  if g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
    # this is also copied into kube-setup-jupyterhub
    for name in "${GEN3_HOME}/kube/services/netpolicy/base/"*.yaml; do
      (yq -r . < "$name") | jq -r --arg namespace "$notebookNamespace" '.metadata.namespace=$namespace' | g3kubectl apply -f -
    done
    gen3 netpolicy external | jq -r --arg namespace "$notebookNamespace" '.spec.podSelector={} | .metadata.namespace=$namespace' | g3kubectl apply -f
  fi
}

apply_all() {
  apply_gen3 "$@"
  apply_jupyter "$@"
}

# main -----------------------------------

command="$1"
shift
case "$command" in 
  "jupyter"):
    apply_jupyter "$@"
    ;;
  "service"):
    apply_service "$@"
    ;;
  *)
    apply_all "$@"
    ;;
esac
