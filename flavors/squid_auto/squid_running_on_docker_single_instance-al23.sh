#!/bin/bash


###############################################################
# variables
###############################################################
DISTRO=$(awk -F '[="]*' '/^NAME/ { print $2 }' < /etc/os-release)
WORK_USER="ubuntu"
if [[ $DISTRO == "Amazon Linux" ]]; then
  WORK_USER="ec2-user"
  if [[ $(awk -F '[="]*' '/^VERSION_ID/ { print $2 }' < /etc/os-release) == "2023" ]]; then
    DISTRO="al2023"
  fi
fi
HOME_FOLDER="/home/${WORK_USER}"
SUB_FOLDER="${HOME_FOLDER}/cloud-automation"
MAGIC_URL="http://169.254.169.254/latest/meta-data/"
get_imds_token() {
  curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
       -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"
}

imds() {
  # $1 = path under /latest/
  local token="${IMDS_TOKEN:-}"
  if [[ -z "$token" ]]; then
    token=$(get_imds_token || true)
    IMDS_TOKEN="$token"
  fi
  if [[ -n "$token" ]]; then
    curl -sS -H "X-aws-ec2-metadata-token: $token" "http://169.254.169.254/latest/$1"
  else
    # Fallback if IMDSv1 is allowed (won't work if IMDSv2 is enforced)
    curl -sS "http://169.254.169.254/latest/$1"
  fi
}

# Prefer the instance-identity document for region & AZ (robust, single JSON fetch)
IID_JSON="$(imds dynamic/instance-identity/document)"
REGION="$(echo "$IID_JSON" | jq -r '.region // empty')"
AVAILABILITY_ZONE="$(echo "$IID_JSON" | jq -r '.availabilityZone // empty')"

# Fallbacks if somehow missing
if [[ -z "$REGION" ]]; then
  # Try metadata placement endpoint (with token)
  AVAILABILITY_ZONE="$(imds meta-data/placement/availability-zone || true)"
  [[ -n "$AVAILABILITY_ZONE" ]] && REGION="${AVAILABILITY_ZONE%[a-z]}"
fi

# As a last resort, let env or AWS CLI config provide region
if [[ -z "$REGION" ]]; then
  REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
fi

if [[ -z "$REGION" ]]; then
  echo "FATAL: could not determine AWS region from IMDSv2 / environment."
  exit 1
fi
DOCKER_DOWNLOAD_URL="https://download.docker.com/linux/ubuntu"
AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
SQUID_CONFIG_DIR="/etc/squid"
SQUID_LOGS_DIR="/var/log/squid"
SQUID_CACHE_DIR="/var/cache/squid"
SQUID_PID_DIR="/var/run/squid"
SQUID_IMAGE_TAG="master" #"feat_ha-squid"
#SQUID_VERSION="squid-4.14"

HOSTNAME=$(command -v hostname)

# Copy the authorized keys for the admin user
cp ${SUB_FOLDER}/files/authorized_keys/squid_authorized_keys_admin ${HOME_FOLDER}/.ssh/authorized_keys


###############################################################
# get any variables we want coming from terraform variables
###############################################################
if [ $# -eq 0 ];
then
    echo "No arguments supplied"
else
    #OIFS=$IFS
    echo $1
    IFS=';' read -ra ADDR <<< "$1"
    echo ${ADDR[@]}
    for i in "${ADDR[@]}"; do
      echo $i
      if [[ $i = *"cwl_group"* ]];
      then
        CWL_GROUP="$(echo ${i} | cut -d= -f2)"
      elif [[ ${i} = *"squid_image"* ]];
      then
        SQUID_IMAGE_TAG="$(echo ${i} | cut -d= -f2)"
#      elif [[ ${i} = *"squid_version"* ]];
#      then
#        SQUID_VERSION="$(echo ${i} | cut -d= -f2)"
      fi
    done
    echo $1
fi


function install_basics(){
  if [[ $DISTRO == "Ubuntu" ]]; then
    apt -y install atop
  elif [[ $DISTRO == "al2023" ]]; then
    sudo dnf install cronie nc -y
  fi
}

function install_docker(){

  ###############################################################
  # Docker
  ###############################################################
  # Install docker from sources
  if [[ $DISTRO == "Ubuntu" ]]; then
    curl -fsSL ${DOCKER_DOWNLOAD_URL}/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] ${DOCKER_DOWNLOAD_URL} $(lsb_release -cs) stable"
    apt update
    apt install -y docker-ce
  else
    sudo yum update -y
    sudo yum install -y docker
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
  fi
  mkdir -p /etc/docker
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/docker-daemon.json /etc/docker/daemon.json
  chmod -R 0644 /etc/docker
  usermod -a -G docker ${WORK_USER}
}

function set_squid_config(){

  ###############################################################
  # Squid configuration files
  ###############################################################
  mkdir -p ${SQUID_CONFIG_DIR}/ssl
  cp ${SUB_FOLDER}/files/squid_whitelist/ftp_whitelist ${SQUID_CONFIG_DIR}/ftp_whitelist
  cp ${SUB_FOLDER}/files/squid_whitelist/web_whitelist ${SQUID_CONFIG_DIR}/web_whitelist
  cp ${SUB_FOLDER}/files/squid_whitelist/web_wildcard_whitelist ${SQUID_CONFIG_DIR}/web_wildcard_whitelist
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/squid.conf ${SQUID_CONFIG_DIR}/squid.conf
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/cachemgr.conf ${SQUID_CONFIG_DIR}/cachemgr.conf
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/errorpage.css ${SQUID_CONFIG_DIR}/errorpage.css
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/mime.conf ${SQUID_CONFIG_DIR}/mime.conf

  #####################
  # for HTTPS
  #####################
  openssl genrsa -out ${SQUID_CONFIG_DIR}/ssl/squid.key 2048
  openssl req -new -key ${SQUID_CONFIG_DIR}/ssl/squid.key -out ${SQUID_CONFIG_DIR}/ssl/squid.csr -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid'
  openssl x509 -req -days 3650 -in ${SQUID_CONFIG_DIR}/ssl/squid.csr -signkey ${SQUID_CONFIG_DIR}/ssl/squid.key -out ${SQUID_CONFIG_DIR}/ssl/squid.crt
  cat ${SQUID_CONFIG_DIR}/ssl/squid.key ${SQUID_CONFIG_DIR}/ssl/squid.crt | sudo tee ${SQUID_CONFIG_DIR}/ssl/squid.pem
  mkdir -p ${SQUID_LOGS_DIR} ${SQUID_CACHE_DIR}
  chown -R nobody:nogroup ${SQUID_LOGS_DIR} ${SQUID_CACHE_DIR} ${SQUID_CONFIG_DIR}
}



function configure_iptables(){

  ###############################################################
  # firewall or basically iptables
  ###############################################################
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/iptables-docker.conf /etc/iptables.conf
  cp ${SUB_FOLDER}/flavors/squid_auto/startup_configs/iptables-rules /etc/network/if-up.d/iptables-rules

  chown root: /etc/network/if-up.d/iptables-rules
  chmod 0755 /etc/network/if-up.d/iptables-rules

  ## Enable iptables for NAT. We need this so that the proxy can be used transparently
  iptables-restore < /etc/iptables.conf
}


function set_boot_configuration(){
  ###############################################################
  # init files or script
  ###############################################################
  #cp /etc/rc.local /etc/rc.local.bak
  #sed -i 's/^exit/#exit/' /etc/rc.local

  cat > /etc/squid_boot.sh <<EOF
#!/bin/bash
if [ -f /var/run/squid/squid.pid ];
then
  rm /var/run/squid/squid.pid
fi

if ( docker inspect  squid -f '{{.State}}' > /dev/null 2>&1 );
then
  $(command -v docker) rm squid
fi

# At this point docker is already up and we dont want to restore the firewall and wipte all
# docker nat rules
#iptables-restore < /etc/iptables.conf

iptables -t nat -A PREROUTING ! -i docker0 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 3129
iptables -t nat -A PREROUTING ! -i docker0 -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 3130

$(command -v docker) run --name squid --network=host -d \
    --volume ${SQUID_LOGS_DIR}:${SQUID_LOGS_DIR} \
    --volume ${SQUID_PID_DIR}:${SQUID_PID_DIR} \
    --volume ${SQUID_CACHE_DIR}:${SQUID_CACHE_DIR} \
    --volume ${SQUID_CONFIG_DIR}:${SQUID_CONFIG_DIR}:ro \
    quay.io/cdis/squid:${SQUID_IMAGE_TAG}
exit 0

EOF

  # create the service to work onlu on boot with ExecStart
  cat > /etc/systemd/system/squid_boot.service <<EOF
[Unit]
Description=squid_boot script

[Service]
ExecStart=/etc/squid_boot.sh

[Install]
WantedBy=multi-user.target
EOF

  chmod +x /etc/systemd/system/squid_boot.service
  systemctl enable squid_boot

  # Copy the updatewhitelist.sh script to the home directory
  cp  ${SUB_FOLDER}/flavors/squid_auto/updatewhitelist-docker.sh ${HOME_FOLDER}/updatewhitelist.sh
  chmod +x ${HOME_FOLDER}/updatewhitelist.sh
  cp  ${SUB_FOLDER}/flavors/squid_auto/healthcheck.sh ${HOME_FOLDER}/healthcheck.sh
  chmod +x ${HOME_FOLDER}/healthcheck.sh

  crontab -l > crontab_file; echo "*/15 * * * * ${HOME_FOLDER}/updatewhitelist.sh >/dev/null 2>&1" >> crontab_file
  echo "*/1 * * * * ${HOME_FOLDER}/healthcheck.sh >/dev/null 2>&1" >> crontab_file
  #chown -R ${WORK_USER}. ${HOME_FOLDER}
  crontab crontab_file

  cat > /etc/cron.daily/squid <<EOF
#!/bin/bash
# Let's rotate the logs daily
$(command -v docker) exec squid squid -k rotate
EOF

  chmod +x /etc/cron.daily/squid
}

function install_awslogs {

  ###############################################################
  # download and install awslogs
  ###############################################################
  if [[ $DISTRO == "Ubuntu" ]]; then
    wget ${AWSLOGS_DOWNLOAD_URL} -O amazon-cloudwatch-agent.deb
    dpkg -i -E ./amazon-cloudwatch-agent.deb
  elif [[ $DISTRO == "Amazon Linux" ]]; then
    sudo yum install amazon-cloudwatch-agent nc -y
  elif [[ $DISTRO == "al2023" ]]; then
    sudo dnf install amazon-cloudwatch-agent -y
  fi

  # Configure the AWS logs

  instance_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
  IFS=. read ip1 ip2 ip3 ip4 <<< "$instance_ip"

  cat >> /opt/aws/amazon-cloudwatch-agent/bin/config.json <<EOF
{
        "agent": {
                "run_as_user": "root"
        },
        "logs": {
                "logs_collected": {
                        "files": {
                                "collect_list": [
                                        {
                                                "file_path": "/var/log/auth.log",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "http_proxy-auth-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "${SQUID_LOGS_DIR}/access.log*",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "http_proxy-squid_access-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}"
                                        },
                                        {
                                                "file_path": "/var/log/syslog",
                                                "log_group_name": "${CWL_GROUP}",
                                                "log_stream_name": "http_proxy-syslog-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        }
                                ]
                        }
                }
        }
}
EOF

  if [ -v CWL_GROUP ];
  then
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
    systemctl enable amazon-cloudwatch-agent.service
    systemctl start amazon-cloudwatch-agent.service
  fi
}


function set_user() {

  if ! [ -z ${1} ];
  then
    local username=${1}
  else
    exit
  fi

  useradd -m -s /bin/bash ${username}
  mkdir -m 700 /home/${username}/.ssh
  cp -r ${HOME_FOLDER}/cloud-automation /home/${username}
  cp /home/${username}/cloud-automation/files/authorized_keys/squid_authorized_keys_user /home/${username}/.ssh/authorized_keys
  chown -R ${username}. /home/${username}
}

configure_routing_and_dns() {
  set -euo pipefail

  # --- IMDSv2 helpers ---
  get_imds_token() {
    curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
         -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"
  }
  imds() {
    local path="$1"
    if [[ -z "${IMDS_TOKEN:-}" ]]; then
      IMDS_TOKEN="$(get_imds_token || true)"
    fi
    if [[ -n "${IMDS_TOKEN:-}" ]]; then
      curl -sS -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
           "http://169.254.169.254/latest/${path}"
    else
      # Fallback if IMDSv1 is allowed (may be disabled by policy)
      curl -sS "http://169.254.169.254/latest/${path}"
    fi
  }

  # --- Gather identity & networking from IMDS (robust & fast) ---
  IID_JSON="$(imds dynamic/instance-identity/document)"
  REGION="$(echo "$IID_JSON" | jq -r '.region')"
  AVAILABILITY_ZONE="$(echo "$IID_JSON" | jq -r '.availabilityZone')"
  INSTANCE_ID="$(echo "$IID_JSON" | jq -r '.instanceId')"

  # Primary interface info
  MAC="$(imds meta-data/network/interfaces/macs/ | awk 'NR==1{print substr($0,1,length($0)-1)}')"
  if [[ -z "$MAC" ]]; then
    echo "FATAL: could not read primary interface MAC from IMDS." >&2
    return 1
  fi
  VPC_ID="$(imds meta-data/network/interfaces/macs/$MAC/vpc-id || true)"
  NETWORK_INTERFACE_ID="$(imds meta-data/network/interfaces/macs/$MAC/interface-id || true)"
  PRIVATE_IP="$(imds meta-data/network/interfaces/macs/$MAC/local-ipv4s | awk 'NR==1' || true)"

  if [[ -z "$REGION" || -z "$VPC_ID" || -z "$NETWORK_INTERFACE_ID" || -z "$PRIVATE_IP" ]]; then
    echo "FATAL: missing required IMDS values:
      REGION='$REGION'
      VPC_ID='$VPC_ID'
      ENI='$NETWORK_INTERFACE_ID'
      PRIVATE_IP='$PRIVATE_IP'" >&2
    return 1
  fi

  echo "Using REGION=$REGION VPC_ID=$VPC_ID ENI=$NETWORK_INTERFACE_ID INSTANCE_ID=$INSTANCE_ID PRIVATE_IP=$PRIVATE_IP"

  # --- Upsert default route in the target route tables ---
  for RT_NAME in private_kube eks_private; do
    RT_ID="$(aws ec2 describe-route-tables \
      --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$RT_NAME" \
      --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"

    if [[ -z "$RT_ID" || "$RT_ID" == "None" || "$RT_ID" == "null" ]]; then
      echo "Could not find route table named '$RT_NAME' in VPC $VPC_ID"
      continue
    fi

    echo "Checking route in $RT_NAME ($RT_ID)…"
    EXISTING_ENI="$(aws ec2 describe-route-tables \
      --region "$REGION" --route-table-ids "$RT_ID" \
      --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NetworkInterfaceId" \
      --output text)"

    if [[ "$EXISTING_ENI" == "$NETWORK_INTERFACE_ID" ]]; then
      echo "0.0.0.0/0 already points to this ENI on $RT_NAME"
    else
      # Try replace first; if no route exists, create it
      if ! aws ec2 replace-route \
            --region "$REGION" \
            --route-table-id "$RT_ID" \
            --destination-cidr-block "0.0.0.0/0" \
            --network-interface-id "$NETWORK_INTERFACE_ID" 2>/dev/null; then
        echo "Route not found, creating on $RT_NAME"
        aws ec2 create-route \
          --region "$REGION" \
          --route-table-id "$RT_ID" \
          --destination-cidr-block "0.0.0.0/0" \
          --network-interface-id "$NETWORK_INTERFACE_ID"
      fi
      echo "Upserted 0.0.0.0/0 → $NETWORK_INTERFACE_ID on $RT_NAME"
    fi
  done

  # --- Route53 zone discovery (prefer by-VPC, fallback by name) ---
  ZONE_NAME="internal.io."
  ZONE_ID="$(aws route53 list-hosted-zones-by-vpc \
    --vpc-id "$VPC_ID" --vpc-region "$REGION" \
    --query "HostedZoneSummaries[?Name == '$ZONE_NAME'].HostedZoneId" \
    --output text 2>/dev/null || true)"

  if [[ -z "$ZONE_ID" || "$ZONE_ID" == "None" || "$ZONE_ID" == "null" ]]; then
    # Fallback: find the zone by name in this account
    ZONE_ID="$(aws route53 list-hosted-zones \
      --query "HostedZones[?Name == '$ZONE_NAME' && Config.PrivateZone == \`true\`].Id" \
      --output text 2>/dev/null | sed 's#/hostedzone/##' || true)"
    if [[ -z "$ZONE_ID" ]]; then
      echo "No private hosted zone named ${ZONE_NAME%?} found in account (and none associated with VPC $VPC_ID)."
      return 0
    fi
    # Optional: ensure association so lookups work from this VPC
    echo "Associating VPC $VPC_ID with hosted zone $ZONE_ID (if not already)…"
    aws route53 associate-vpc-with-hosted-zone \
      --hosted-zone-id "$ZONE_ID" \
      --vpc "VPCRegion=$REGION,VPCId=$VPC_ID" \
      --comment "Ensure association for $ZONE_NAME" >/dev/null 2>&1 || true
  fi

  echo "Upserting A record cloud-proxy.internal.io → $PRIVATE_IP in zone $ZONE_ID"
  aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "{
      \"Comment\": \"Ensure cloud-proxy.internal.io A record exists\",
      \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"cloud-proxy.internal.io\",
          \"Type\": \"A\",
          \"TTL\": 60,
          \"ResourceRecords\": [{\"Value\": \"$PRIVATE_IP\"}]
        }
      }]
    }"
}



function init(){
  install_basics
  install_docker
  set_squid_config
  configure_iptables
  set_boot_configuration
  set_user sftpuser
  install_awslogs
  configure_routing_and_dns
}

function main(){
  init
  # If we don't restart the service, iptables might not load properly sometimes
  systemctl restart docker
  $(command -v docker) run --name squid --network=host -d \
      --volume ${SQUID_LOGS_DIR}:${SQUID_LOGS_DIR} \
      --volume ${SQUID_PID_DIR}:${SQUID_PID_DIR} \
      --volume ${SQUID_CACHE_DIR}:${SQUID_CACHE_DIR} \
      --volume ${SQUID_CONFIG_DIR}:${SQUID_CONFIG_DIR}:ro \
       quay.io/cdis/squid:${SQUID_IMAGE_TAG}

  max_attempts=10
  attempt_counter=0
  while [ $attempt_counter -lt $max_attempts ]; do
    #((attempt_counter++))
    sleep 10
    if [[ -z "$(sudo lsof -i:3128)" ]]; then
      echo "Squid not healthy, restarting."
      docker restart squid
    else
      echo "Squid healthy"
    fi
  done
}

main
