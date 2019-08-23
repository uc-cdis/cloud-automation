#
# Some helpers for `kube-setup-netpolicy`
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ------------------------

#
# Return true if $1 looks like an IP address
#
gen3_net_isIp() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}


#
# Generate a network policy that
# allows communication to all CIDR's except 10/8 and 172.16/12 and 169.254/16
#
gen3_net_external_access() {
  local basePolicy

  basePolicy="$(mktemp "$XDG_RUNTIME_DIR/netpolicy.json_XXXXXX")"
  cidrList="$(mktemp "$XDG_RUNTIME_DIR/cidrList.ndjson_XXXXXX")"
  cat - > "$basePolicy" <<EOM
{
    "apiVersion": "extensions/v1beta1",
    "kind": "NetworkPolicy",
    "metadata": {
        "name": "netpolicy-external-egress"
    },
    "spec": {
        "egress": [
            {
                "to": [
                    {
                        "ipBlock": {
                            "cidr": "0.0.0.0/0",
                            "except": [
                              "169.254.0.0/16",
                              "172.16.0.0/12",
                              "10.0.0.0/8"
                            ]
                        }
                    }
                ]
            }
        ],
        "podSelector": {
            "matchLabels": {
                "internet": "yes"
            }
        },
        "policyTypes": [
            "Egress"
        ]
    }
}
EOM

  # whitelist the squid proxy if we can identify it
  local squidAddr
  local result
  squidAddr="$(dig +short cloud-proxy.internal.io)"
  if gen3_net_isIp "$squidAddr"; then
    cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "${squidAddr}/32"
  }
}
EOM
    jq -r -e --slurpfile data "$cidrList" '.spec.egress[1].to=$data' < "$basePolicy"
  else
    cat "$basePolicy"
  fi
  result=$?
  rm "$basePolicy"
  rm "$cidrList"
  return "$result"
}


#
# Generate a policy with a given name and an illegal podSelector
# (to be filled in by the caller)
# that grants egress to a list of cidrs
#
# @param name
# @param cidr1, cidr2, ...
#
gen3_net_cidr_access() {
  if [[ $# -lt 2 ]]; then
    gen3_log_err "gen3_net_cidr_access" "must specify at least name and 1 cidr: $@"
    return 1
  fi
  local name
  local cidr
  local cidrList
  local result

  cidrList="$(mktemp "$XDG_RUNTIME_DIR/cidrList.ndjson_XXXXXX")"
  name="$1"
  shift
  while [[ $# -gt 0 ]]; do
    cidr="$1"
    shift
    cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "${cidr}"
  }
}
EOM
  done
  (cat - <<EOM
{
    "apiVersion": "extensions/v1beta1",
    "kind": "NetworkPolicy",
    "metadata": {
        "name": "$name"
    },
    "spec": {
        "egress": [
            {
                "to": [
                    {
                        "ipBlock": {
                            "cidr": "0.0.0.0/32"
                        }
                    }
                ]
            }
        ],
        "podSelector": "illegal",
        "policyTypes": [
            "Egress"
        ]
    }
}
EOM
  ) | jq -r -e --slurpfile data "$cidrList" '.spec.egress[0].to=$data'
  result=$?
  rm "$cidrList"
  return $result
}


#
# Generate a network policy that allows access to S3 CIDR ranges
#
gen3_net_s3_access() {
  local awsCacheFile="${GEN3_CACHE_DIR}/aws-ip-ranges.json"
  local s3CacheFile="${GEN3_CACHE_DIR}/s3-ranges.json"

  if [[ (! -f "$awsCacheFile") || (! -f "$s3CacheFile") ]] || (gen3_time_since ipranges_sync is 900); then
    curl -s https://ip-ranges.amazonaws.com/ip-ranges.json -o "$awsCacheFile"
    if ! (jq -e -r '.prefixes | map(select(.service=="S3" and .region=="us-east-1"))' < "$awsCacheFile" ) > "$s3CacheFile"; then
      gen3_log_err "gen3_net_s3_access" "failed to refresh AWS address ranges"
      return 1
    fi
  fi

  gen3_net_cidr_access "netpolicy-s3" $(jq -r '. | map(.ip_prefix) | .[]' < "$s3CacheFile") | jq -r -e '.spec.podSelector = { "matchLabels": { "s3":"yes" } }'
}

#
# Generate a networkpolicy that grants egress to the RDS database
# associated with the given service for pods labeled with
# `app=$serviceName`
#
# @param serviceName 
#
gen3_net_db_access() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_net_db_access" "require serviceName argument"
    return 1
  fi
  local serviceName
  local hostname
  local ip
  serviceName="$1"
  hostname="$(gen3 db creds "$serviceName" | jq -r .db_host)"
  ip="$(dig +short "$hostname")"
  if ! gen3_net_isIp "$ip"; then
    gen3_log_err "gen3_net_db_access" "unable to determine address of $serviceName database"
    return 1
  fi
  gen3_net_cidr_access "netpolicy-db$serviceName" "$ip/32" | jq -r -e --arg serviceName "$serviceName" '.spec.podSelector = { "matchLabels": { "app":$serviceName  } }'
}

#
# Generate a networkpolicy that grants egress to the RDS database
# associated with the given service for pods labeled with
# `db${serviceName}=yes`
#
# @param serviceName 
#
gen3_net_bydb_access() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "gen3_net_bydb_access" "require serviceName argument"
    return 1
  fi
  local serviceName
  serviceName="$1"
  (gen3_net_db_access "$@" || echo "break") | jq -r -e --arg serviceKey "db$serviceName" '.spec.podSelector = { "matchLabels": { ($serviceKey): "yes"  } } | .metadata.name+="-bydb"'
}


#
# Generate a policy that allows ingress to pods
# labeled with `app` equal to the first argument from pods
# labeled with `app` equal to subsequent arguments
#
gen3_net_ingress_to_app() {
  local app
  if [[ $# -lt 2 ]]; then
    gen3_log_err "gen3_net_ingress_to_app" "empty spec $@"
    return 0
  fi
  app="$1"
  shift
  (cat - <<EOM
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: netpolicy-ingress-to-$app
spec:
  podSelector:
    matchLabels:
      app: $app
  ingress:
    - from:
      - podSelector:
          matchExpressions:
          - { key: app, operator: In, values: [] }
  policyTypes:
   - Ingress
EOM
  ) | yq -r . | jq -e --arg apps "$*" -r '.spec.ingress[0].from[0].podSelector.matchExpressions[0].values = ($apps | split(" +"; "i"))'
}

#
# Generate a policy that allows egress to pods
# labeled with `app` equal to the first argument from pods
# labeled with `app` equal to subsequent arguments
#
gen3_net_egress_to_app() {
  local app
  if [[ $# -lt 2 ]]; then
    gen3_log_err "gen3_net_ingress_to_app" "empty spec $@"
    return 0
  fi
  app="$1"
  shift
  (cat - <<EOM
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: netpolicy-egress-to-$app
spec:
  podSelector:
    matchExpressions:
    - { key: app, operator: In, values: [] }
  egress:
    - to:
      - podSelector:
          matchLabels:
            app: $app
  policyTypes:
   - Egress
EOM
  ) | yq -r . | jq -e --arg apps "$*" -r '.spec.podSelector.matchExpressions[0].values = ($apps | split(" +"; "i"))'
}

# main -------------------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  command="$1"
  shift
  case "$command" in
    "external")
      gen3_net_external_access "$@";
      ;;
    "s3")
      gen3_net_s3_access "$@"
      ;;
    "cidr")
      gen3_net_cidr_access "$@"
      ;;
    "db")
      gen3_net_db_access "$@"
      ;;
    "bydb")
      gen3_net_bydb_access "$@"
      ;;
    ingress[tT]o)
      gen3_net_ingress_to_app "$@"
      ;;
    egress[tT]o)
      gen3_net_egress_to_app "$@"
      ;;
    is[Ii]p)
      gen3_net_isIp "$@"
      ;;
    *)
      gen3 help networkpolicy
      ;;
  esac
  exit $?
fi
