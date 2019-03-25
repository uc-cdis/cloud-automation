#!/bin/bash
#
# Apply network policy to the core services of the commons
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

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

credsPath="$(gen3_secrets_folder)/creds.json"
if [[ -f "$credsPath" ]]; then # setup netpolicy
  # google config this is already an IP
  gdcapi_db_host=$(jq -r .gdcapi.db_host < "$credsPath")
  indexd_db_host=$(jq -r .indexd.db_host < "$credsPath")
  fence_db_host=$(jq -r .fence.db_host < "$credsPath")

  GDCAPIDB_IP="$(name2IP "$gdcapi_db_host")"
  INDEXDDB_IP="$(name2IP "$indexd_db_host")"
  FENCEDB_IP="$(name2IP "$fence_db_host")"

  #
  # Replace this with something better later ...
  # this works across AWS and GCP
  #
  CLOUDPROXY_CIDR="172.0.0.0/8"

  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_fence_templ.yaml" GEN3_FENCEDB_IP "$FENCEDB_IP" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_google-sa-validation_templ.yaml" GEN3_FENCEDB_IP "$FENCEDB_IP" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_indexd_templ.yaml" GEN3_INDEXDDB_IP "$INDEXDDB_IP" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_peregrine_templ.yaml" GEN3_GDCAPIDB_IP "$GDCAPIDB_IP" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_wts_templ.yaml" GEN3_GDCAPIDB_IP "$GDCAPIDB_IP" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_pidgin_templ.yaml" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_arborist_templ.yaml" GEN3_FENCEDB_IP "$FENCEDB_IP" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_ssjdispatcher_templ.yaml" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_ssjdispatcherjob_templ.yaml" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_sheepdog_templ.yaml" GEN3_GDCAPIDB_IP "$GDCAPIDB_IP" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_portal_templ.yaml" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_revproxy_templ.yaml" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" | g3kubectl apply -f -
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_jenkins_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_allowdns_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_gen3job_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_arranger_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_aws_es_proxy.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_arranger_dashboard_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_tube_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_spark_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_manifestservice_templ.yaml"
  g3kubectl apply -f "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_guppy_templ.yaml"
fi
