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


#
# Allow communication to all CIDR's except 10/8 and 172.16/12
#
externalIPs() {
  local basePolicy
  basePolicy="$(mktemp "$XDG_RUNTIME_DIR/netpolicy.json_XXXXXX")"
  cidrList="$(mktemp "$XDG_RUNTIME_DIR/cidrList.ndjson_XXXXXX")"
  cat - > "$basePolicy" <<EOM
{
    "apiVersion": "extensions/v1beta1",
    "kind": "NetworkPolicy",
    "metadata": {
        "name": "networkpolicy-reuben",
    },
    "spec": {
        "egress": [
            {
                "to": [
                    {
                        "ipBlock": {
                            "cidr": "0.0.0.0/0"
                        }
                    }
                ]
            }
        ],
        "podSelector": {
            "matchLabels": {
                "app": "reuben"
            }
        },
        "policyTypes": [
            "Ingress",
            "Egress"
        ]
    }
}
EOM

  for ip in {1..254}; do
    if [[ "$ip" -ne 10 && "$ip" -ne 172 ]]; then
      cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "${ip}.0.0.0/8"
  }
}
EOM
    fi
  done
  rm "$basePolicy"
}

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

  #
  # Replace this with something better later ...
  # this works across AWS and GCP
  #
  CLOUDPROXY_CIDR="172.0.0.0/8"

  for name in "${GEN3_HOME}/kube/services/netpolicy/networkpolicy"*.yaml; do
    (g3k_kv_filter "${GEN3_HOME}/kube/services/netpolicy/networkpolicy_fence_templ.yaml" GEN3_CLOUDPROXY_CIDR "$CLOUDPROXY_CIDR" "${dbArgs[@]}" | g3kubectl apply -f -) || true
  done
fi
