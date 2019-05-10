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

# lib -------------------------

#
# Deploy network policies that accomodate the
# gen3.io/network-ingress ACL included in gen3 deployments
#
# @param name of the service
#
net_apply_service() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "kube-setup-networkpolicy" "net_apply_service service not specified"
    return 1
  fi
  local name
  name="$1"
  shift
  local yamlPath
  if yamlPath="$(gen3 gitops rollpath "$name" 2> /dev/null)"; then
    if accessList="$(gen3 gitops filter "$yamlPath" | yq -e -r '.metadata.annotations["gen3.io/network-ingress"]')"; then
      accessList="${accessList//,/ }"
      local app
      app="$name"
      # on-off for aws-es-proxy - ugh!
      if [[ "$name" == "aws-es-proxy" ]]; then
        app="esproxy"
      fi
      gen3_log_info "networkpolicy - $app accessible by annotation acl: ${accessList}"
      gen3 netpolicy ingressTo $app $accessList | g3kubectl apply -f -
      gen3 netpolicy egressTo $app $accessList | g3kubectl apply -f -
    else
      gen3_log_info "networkpolicy - $name not accessible by annotation acl"
      # delete previously generated policies if they exist
      g3kubectl delete networkpolicy "netpolicy-ingress-to-$name" > /dev/null 2>&1
      g3kubectl delete networkpolicy "netpolicy-egress-to-$name" > /dev/null 2>&1
    fi
  else
    gen3_log_info "kube_setup_networkpolicy" "failed to retrieve path for service ${name}: $yamlPath"
  fi
}


net_apply_gen3() {
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
}


net_apply_all_services() {
  local name
  #
  # apply ingress/egress rolls from gen3.io/network annotations
  # in the services refrenced by the manifest
  #
  g3k_manifest_lookup .versions | jq -r '. | keys | .[]' | while read -r name; do
    net_apply_service "$name"
  done
}

#
# Apply policy rules to the jupyter/user namespaces
#
net_apply_jupyter() {
  local notebookNamespace
  local name
  notebookNamespace="$(gen3 jupyter j-namespace)"

  if false && g3kubectl get namespace "$notebookNamespace" > /dev/null 2>&1; then
    for name in "${GEN3_HOME}/kube/services/netpolicy/base/"*.yaml; do
      (yq -r . < "$name") | jq -r --arg namespace "$notebookNamespace" '.metadata.namespace=$namespace' | g3kubectl apply -f -
    done
    gen3 netpolicy external | jq -r --arg namespace "$notebookNamespace" '.spec.podSelector={} | .metadata.namespace=$namespace' | g3kubectl apply -f -
    for name in "${GEN3_HOME}/kube/services/netpolicy/user/"*.yaml; do
      (yq -r . < "$name") | jq -r --arg namespace "$notebookNamespace" '.metadata.namespace=$namespace' | g3kubectl apply -f -
    done
  fi
}


#
# Old network policies were named 'networkpolicy-', new ones are 'netpolicy-'
#
net_delete_old_policies() {
  local olds
  if olds="$(g3kubectl get networkpolicies --no-headers 2> /dev/null | awk '{ print $1 }' | grep '^networkpolicy-')"; then
    g3kubectl delete networkpolicies $olds
  fi
}


#
# Accepts "noservice" as arg 1 to indicate to not
# process service annotations - to save time in `gen3 roll all`
#
net_apply_all() {
  net_apply_gen3 "$@"
  net_apply_jupyter "$@"
  if [[ "$1" != "noservice" ]]; then
    net_apply_all_services "$@"
  fi
  net_delete_old_policies "$@"
}


# main -----------------------------------

command="$1"
shift
case "$command" in 
  "jupyter"):
    net_apply_jupyter "$@"
    ;;
  "service"):
    net_apply_service "$@"
    ;;
  "noservice"):
    net_apply_all noservice
    ;;
  *)
    net_apply_all "$@"
    ;;
esac
