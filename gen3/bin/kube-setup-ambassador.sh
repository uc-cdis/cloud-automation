#!/bin/bash
#
# Deploy ambassador into existing commons
# This fragment is pasted into kube-services.sh by kube.tf.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ------------------------

deploy_hatchery_proxy() {
  local namespace="$(gen3 db namespace)"

  g3k_kv_filter ${GEN3_HOME}/kube/services/ambassador/ambassador-rbac.yaml AMBASSADOR_BINDING "name: ambassador-binding-$namespace" CURRENT_NAMESPACE "namespace: $namespace" | g3kubectl apply -f -
  gen3 roll ambassador
  g3kubectl apply -f "${GEN3_HOME}/kube/services/ambassador/ambassador-service.yaml"
  
  gen3_log_info "The ambassador hatchery proxy has been deployed onto the k8s cluster."
}

deploy_api_gateway() {
  if ! g3k_manifest_lookup '.versions["ambassador-gen3"]' 2> /dev/null; then
    gen3_log_info "ambassador api gateway not enabled in manifest"
    return 0
  fi
  gen3 roll ambassador-gen3

  local luaYamlTemp="$(mktemp "$XDG_RUNTIME_DIR/lua.yaml.XXXXXX")"
  cat - > "$luaYamlTemp" <<EOM
apiVersion: ambassador/v1
kind: Module
name: ambassador
ambassador_id: "gen3"
config:
  # see https://www.getambassador.io/reference/core/ambassador/#lua-scripts-lua_scripts
  lua_scripts: |
EOM
  cat "${GEN3_HOME}/kube/services/ambassador-gen3/ambassador-gen3.lua" | awk '{ print "    " $0 }' >> "$luaYamlTemp"
  local luaYamlStr="$(cat "$luaYamlTemp")"
  /bin/rm "$luaYamlTemp"
  yq --arg lua "$luaYamlStr" '.metadata.annotations["getambassador.io/config"]=$lua' < "${GEN3_HOME}/kube/services/ambassador-gen3/ambassador-gen3-service.yaml" | g3kubectl apply -f -
}


deploy_stats_sink() {
  gen3_log_info "stats sink deprecated - ambassador exports :8787/metrics directly"
  return 0
  if ! g3k_manifest_lookup '.versions["statsd-exporter"]' 2> /dev/null; then
    gen3_log_info "statsd-exporter not enabled in manifest"
    return 0
  fi
  gen3 roll statsd-exporter
  g3kubectl apply -f "${GEN3_HOME}/kube/services/statsd-exporter/statsd-exporter-deploy.yaml"
}

# main -------------------

command=""
if [[ $# -gt 0 ]]; then
  command="$1"
  shift
fi

case "$command" in
  "gateway")
    deploy_api_gateway "$@"
    ;;
  "hatchery")
    deploy_hatchery_proxy "$@"
    ;;
  *)
    deploy_hatchery_proxy "$@"
    deploy_api_gateway "$@"
    ;;
esac