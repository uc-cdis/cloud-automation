#!/bin/bash


slack_webhook=$(cat /slackWebhook)

# Should check docker is installed, so it won't run healthcheck during initialization
docker_check=$(which docker)
if [[ ! -z "$docker_check" ]]; then
  if [[ -z "$(sudo lsof -i:3128)" ]]; then
    EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    EC2_REGION=$(echo "$EC2_AVAIL_ZONE" | sed 's/[a-z]$//')
    id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
    if [[ ! -z "$slack_webhook" ]]; then
      vpc_name=$(aws ec2 describe-vpcs --region="$EC2_REGION" --filter="Name=vpc-id, Values=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(curl http://169.254.169.254/latest/meta-data/mac/)/vpc-id)" | jq -r '.Vpcs[].Tags[] | select(.Key=="Name")' | jq -r .Value)
      payload="$(cat - <<EOM
payload={
  "text": "Warning: Healthcheck failed for squid instance ${id} in ${vpc_name}"
}
EOM
)"
      curl --max-time 15 -X POST --data-urlencode "${payload}" "${slack_webhook}" >> /home/ubuntu/log
    fi
    aws autoscaling set-instance-health --instance-id="$id" --health-status Unhealthy --region="$EC2_REGION"
  fi
fi
