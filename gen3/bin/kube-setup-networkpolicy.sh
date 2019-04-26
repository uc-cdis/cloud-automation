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




#......................................

credsPath="$(gen3_secrets_folder)/creds.json"
if [[ -f "$credsPath" ]]; then # setup netpolicy
  # figure out the hostname associated with each service's database
  dbServices=(fence indexd sheepdog)
  tempSecrets="$(mktemp "$XDG_RUNTIME_DIR/secrets.json_XXXXXX")"
  g3kubectl get secrets -o json | jq -r '.items | map(select( .data["dbcreds.json"] and (.metadata.name|test("-g3auto$")))) | map( { "name": .metadata.name })' > "$tempSecrets"
  numSecrets="$(jq -r '. | length' < "$tempSecrets")"
  for ((i=0; i < numSecrets; i++)); do
    service="$(jq -r ".[${i}].name" < "$tempSecrets")"
    service="${service%-g3auto}"
    dbServices+=("$service")
  done
  /bin/rm "$tempSecrets"
  
  dbArgs=()
  for serviceName in "${dbServices[@]}"; do
    host="$(gen3 db creds "$serviceName" | jq -r .db_host)"
    varName="GEN3_${serviceName^^}_DBIP"
    dbArgs+=("$varName" "$(name2IP "$host")")
  done

  notebookNamespace="jupyter-pods"
  namespace="$(gen3 db namespace)"
  if [[ -n "$namespace" && "$namespace" != "default" ]]; then
    notebookNamespace="jupyter-pods-$namespace"
  fi

  # apply base policies in both the commons namespace and the jupyter/user namespace
  for name in "${GEN3_HOME}/kube/services/netpolicy/base/"*.yaml; do
    g3kubectl apply -f "$name"
    (jq -r --arg namespace "$notebookNamespace" '.metadata.namespace=$namespace' < "$name") | g3kubectl apply -f
  done

  # apply gen3 generic policies in commons namespace
  for name in "${GEN3_HOME}/kube/services/netpolicy/gen3/"*.yaml; do
    g3kubectl apply -f "$name"
  done

  # apply service-specific policies
  for name in "${GEN3_HOME}/kube/services/netpolicy/gen3/services/"*.yaml; do
    (g3k_kv_filter "$name" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" NOTEBOOK_NAMESPACE "namespace: $notebookNamespace" "${dbArgs[@]}" | g3kubectl apply -f -) || true
  done

  # apply procedurally-generated policies
  # external internet access in both commons and user namespaces
  gen3 netpolicy external | g3kubectl apply -f
  gen3 netpolicy external | jq -r --arg namespace "$notebookNamespace" '.spec.podSelector={} | .metadata.namespace=$namespace' | g3kubectl apply -f
  # s3 access
  gen3 netpolicy s3 | g3kubectl apply -f
  # db access
  for serviceName in $(gen3 db services); do
    gen3 netpolicy db "$serviceName" | g3kubectl apply -f
  done
fi
