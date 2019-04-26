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
        "name": "networkpolicy-external-egress"
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

  local ip
  # whitelist */8 except 10, 172, and 169 ...
  for ip in {1..254}; do
    if [[ "$ip" -ne 10 && "$ip" -ne 172 && "$ip" -ne 169 ]]; then
      cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "${ip}.0.0.0/8"
  }
}
EOM
    fi
  done
  # whitelist 172.X/12 except 172.16/12
  for ip in {0..15}; do
    if [[ $ip -ne 1 ]]; then
      cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "172.$((ip * 16)).0.0/12"
  }
}
EOM
    fi
  done
  # whitelist 169.X/16 except 169.254/16
  for ip in {0..255}; do
    if [[ $ip -ne 254 ]]; then
      cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "169.${ip}.0.0/16"
  }
}
EOM
    fi
  done
  # whitelist the squid proxy if we can identify it
  local squidAddr
  squidAddr="$(dig +short cloud-proxy.internal.io)"
  if gen3_net_isIp "$squidAddr"; then
    cat - >> "$cidrList" <<EOM
{
  "ipBlock": {
    "cidr": "${squidAddr}/32"
  }
}
EOM
  fi

  local result
  jq -r -e --slurpfile data "$cidrList" '.spec.egress[0].to=$data' < "$basePolicy"
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

  gen3_net_cidr_access "networkpolicy-s3" $(jq -r '. | map(.ip_prefix) | .[]' < "$s3CacheFile") | jq -r -e '.spec.podSelector = { "matchLabels": { "s3":"yes" } }'
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
  gen3_net_cidr_access "networkpolicy-db$serviceName" "$ip/32" | jq -r -e --arg serviceName "$serviceName" '.spec.podSelector = { "matchExpressions": { "app":$serviceName  } }'
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
  (gen3_net_db_access "$@" || echo "break") | jq -r -e --arg serviceKey "db$serviceName" '.spec.podSelector = { "matchExpressions": { ($serviceKey): "yes"  } } | .metadata.name+="-bydb"'
}

# main -------------------------------

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
  "isIp")
    gen3_net_isIp "$@"
    ;;
  "isip")
    gen3_net_isIp "$@"
    ;;
  *)
    gen3 help networkpolicy
    ;;
esac
exit $?
