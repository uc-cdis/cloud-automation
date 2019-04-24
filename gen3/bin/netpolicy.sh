#
# Some helpers for `kube-setup-netpolicy`
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ------------------------

#
# Generate a network policy that
# allows communication to all CIDR's except 10/8 and 172.16/12 and 169.254/16
#
# @param namespace optional namespace verride
#
gen3_net_external_access() {
  local namespace
  local basePolicy

  if [[ $# -gt 0 ]]; then
    namespace="$1"
    shift
  fi
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
  local result
  if [[ -n "$namespace" ]]; then
    jq -r -e --arg namespace "$namespace" --slurpfile data "$cidrList" '.spec.egress[0].to=$data | .metadata.namespace=$namespace' < "$basePolicy"
  else
    jq -r -e --slurpfile data "$cidrList" '.spec.egress[0].to=$data' < "$basePolicy"
  fi
  result=$?
  rm "$basePolicy"
  rm "$cidrList"
  return "$result"
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
  local cidr
  local cidrList
  local result
  cidrList="$(mktemp "$XDG_RUNTIME_DIR/cidrList.ndjson_XXXXXX")"

  for cidr in $(jq -r '. | map(.ip_prefix) | .[]' < "$s3CacheFile"); do
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
        "name": "networkpolicy-s3"
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
                "s3": "yes"
            }
        },
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
  *)
    gen3 help networkpolicy
    ;;
esac
exit $?
