#
# Little helper to reboot an ec2 instance by private IP address.
# Assumes the current AWS_PROFILE is accurate
#
g3k_ec2_reboot() {
  local ipAddr
  local id
  ipAddr="$1"
  if [[ -z "$ipAddr" ]]; then
    echo "Use: g3k ec2 reboot private-ip-address"
    return 1
  fi
  (
    set -e
    id=$(gen3 aws ec2 describe-instances --filter "Name=private-ip-address,Values=$ipAddr" --query 'Reservations[*].Instances[*].[InstanceId]' | jq -r '.[0][0][0]')
    if [[ -z "$id" ]]; then
      echo "could not find instance with private ip $ipAddr" 1>&2
      exit 1
    fi
    gen3 aws ec2 reboot-instances --instance-ids "$id"
  )
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  g3k_ec2_reboot "$@"
fi
