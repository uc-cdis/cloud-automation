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

###############################################################
# configurable repo/file locations
###############################################################
AUTOMATION_ROOT="${SUB_FOLDER}"

SSH_KEYS_REPO=""
SSH_KEYS_REPO_DIR="/opt/ssh-keys"
SSH_ADMIN_KEYS_FILE="files/authorized_keys/squid_authorized_keys_admin"
SSH_USER_KEYS_FILE="files/authorized_keys/squid_authorized_keys_user"

WHITELIST_REPO=""
WHITELIST_REPO_DIR="/opt/squid-whitelists"
FTP_WHITELIST_FILE="files/squid_whitelist/ftp_whitelist"
WEB_WHITELIST_FILE="files/squid_whitelist/web_whitelist"
WEB_WILDCARD_WHITELIST_FILE="files/squid_whitelist/web_wildcard_whitelist"

SCRIPT_REPO=""
SCRIPT_REPO_DIR="/opt/squid-scripts"
UPDATEWHITELIST_SCRIPT_FILE="flavors/squid_auto/updatewhitelist-docker.sh"
HEALTHCHECK_SCRIPT_FILE="flavors/squid_auto/healthcheck.sh"

if [[ $DISTRO == "al2023" ]]; then
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id -H "X-aws-ec2-metadata-token: $TOKEN")
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
  AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone -H "X-aws-ec2-metadata-token: $TOKEN")
else
  AVAILABILITY_ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
  REGION=$(echo ${AVAILABILITY_ZONE::-1})
  EC2_INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id -s)
fi

DOCKER_DOWNLOAD_URL="https://download.docker.com/linux/ubuntu"
AWSLOGS_DOWNLOAD_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
SQUID_CONFIG_DIR="/etc/squid"
SQUID_LOGS_DIR="/var/log/squid"
SQUID_CACHE_DIR="/var/cache/squid"
SQUID_PID_DIR="/var/run/squid"
SQUID_IMAGE_TAG="master"

HOSTNAME=$(command -v hostname)

###############################################################
# get any variables we want coming from terraform variables
###############################################################
if [ $# -eq 0 ]; then
  echo "No arguments supplied"
else
  echo "$1"
  IFS=';' read -ra ADDR <<< "$1"
  echo "${ADDR[@]}"

  for i in "${ADDR[@]}"; do
    echo "$i"

    if [[ $i = cwl_group=* ]]; then
      CWL_GROUP="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = squid_image=* ]]; then
      SQUID_IMAGE_TAG="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = automation_root=* ]]; then
      AUTOMATION_ROOT="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = ssh_keys_repo=* ]]; then
      SSH_KEYS_REPO="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = ssh_keys_repo_dir=* ]]; then
      SSH_KEYS_REPO_DIR="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = ssh_admin_keys_file=* ]]; then
      SSH_ADMIN_KEYS_FILE="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = ssh_user_keys_file=* ]]; then
      SSH_USER_KEYS_FILE="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = whitelist_repo=* ]]; then
      WHITELIST_REPO="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = whitelist_repo_dir=* ]]; then
      WHITELIST_REPO_DIR="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = ftp_whitelist_file=* ]]; then
      FTP_WHITELIST_FILE="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = web_whitelist_file=* ]]; then
      WEB_WHITELIST_FILE="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = web_wildcard_whitelist_file=* ]]; then
      WEB_WILDCARD_WHITELIST_FILE="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = script_repo=* ]]; then
      SCRIPT_REPO="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = script_repo_dir=* ]]; then
      SCRIPT_REPO_DIR="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = updatewhitelist_script_file=* ]]; then
      UPDATEWHITELIST_SCRIPT_FILE="$(echo "$i" | cut -d= -f2-)"

    elif [[ $i = healthcheck_script_file=* ]]; then
      HEALTHCHECK_SCRIPT_FILE="$(echo "$i" | cut -d= -f2-)"
    fi
  done

  echo "$1"
fi

function install_basics(){
  if [[ $DISTRO == "Ubuntu" ]]; then
    apt update
    apt -y install atop git
  elif [[ $DISTRO == "al2023" ]]; then
    sudo dnf install cronie nc git -y
  else
    sudo yum install git nc -y
  fi
}

function resolve_file(){
  local root_dir="$1"
  local file_path="$2"

  if [[ "${file_path}" = /* ]]; then
    echo "${file_path}"
  else
    echo "${root_dir}/${file_path}"
  fi
}

function prepare_external_files(){
  SSH_KEYS_ROOT="${AUTOMATION_ROOT}"
  WHITELIST_ROOT="${AUTOMATION_ROOT}"
  SCRIPT_ROOT="${AUTOMATION_ROOT}"

  if [[ -n "${SSH_KEYS_REPO}" ]]; then
    rm -rf "${SSH_KEYS_REPO_DIR}"
    git clone "${SSH_KEYS_REPO}" "${SSH_KEYS_REPO_DIR}"
    SSH_KEYS_ROOT="${SSH_KEYS_REPO_DIR}"
  fi

  if [[ -n "${WHITELIST_REPO}" ]]; then
    rm -rf "${WHITELIST_REPO_DIR}"
    git clone "${WHITELIST_REPO}" "${WHITELIST_REPO_DIR}"
    WHITELIST_ROOT="${WHITELIST_REPO_DIR}"
  fi

  if [[ -n "${SCRIPT_REPO}" ]]; then
    rm -rf "${SCRIPT_REPO_DIR}"
    git clone "${SCRIPT_REPO}" "${SCRIPT_REPO_DIR}"
    SCRIPT_ROOT="${SCRIPT_REPO_DIR}"
  fi

  SSH_ADMIN_KEYS_FILE="$(resolve_file "${SSH_KEYS_ROOT}" "${SSH_ADMIN_KEYS_FILE}")"
  SSH_USER_KEYS_FILE="$(resolve_file "${SSH_KEYS_ROOT}" "${SSH_USER_KEYS_FILE}")"

  FTP_WHITELIST_FILE="$(resolve_file "${WHITELIST_ROOT}" "${FTP_WHITELIST_FILE}")"
  WEB_WHITELIST_FILE="$(resolve_file "${WHITELIST_ROOT}" "${WEB_WHITELIST_FILE}")"
  WEB_WILDCARD_WHITELIST_FILE="$(resolve_file "${WHITELIST_ROOT}" "${WEB_WILDCARD_WHITELIST_FILE}")"

  UPDATEWHITELIST_SCRIPT_FILE="$(resolve_file "${SCRIPT_ROOT}" "${UPDATEWHITELIST_SCRIPT_FILE}")"
  HEALTHCHECK_SCRIPT_FILE="$(resolve_file "${SCRIPT_ROOT}" "${HEALTHCHECK_SCRIPT_FILE}")"
}

function require_file(){
  local file_path="$1"

  if [[ ! -f "${file_path}" ]]; then
    echo "Required file missing: ${file_path}"
    exit 1
  fi
}

function set_admin_authorized_keys(){
  mkdir -p "${HOME_FOLDER}/.ssh"
  chmod 700 "${HOME_FOLDER}/.ssh"

  require_file "${SSH_ADMIN_KEYS_FILE}"

  cp "${SSH_ADMIN_KEYS_FILE}" "${HOME_FOLDER}/.ssh/authorized_keys"
  chown -R "${WORK_USER}." "${HOME_FOLDER}/.ssh"
  chmod 600 "${HOME_FOLDER}/.ssh/authorized_keys"
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
  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/docker-daemon.json" /etc/docker/daemon.json
  chmod -R 0644 /etc/docker
  usermod -a -G docker "${WORK_USER}"
}

function set_squid_config(){

  ###############################################################
  # Squid configuration files
  ###############################################################
  mkdir -p "${SQUID_CONFIG_DIR}/ssl"

  require_file "${FTP_WHITELIST_FILE}"
  require_file "${WEB_WHITELIST_FILE}"
  require_file "${WEB_WILDCARD_WHITELIST_FILE}"

  cp "${FTP_WHITELIST_FILE}" "${SQUID_CONFIG_DIR}/ftp_whitelist"
  cp "${WEB_WHITELIST_FILE}" "${SQUID_CONFIG_DIR}/web_whitelist"
  cp "${WEB_WILDCARD_WHITELIST_FILE}" "${SQUID_CONFIG_DIR}/web_wildcard_whitelist"

  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/squid.conf" "${SQUID_CONFIG_DIR}/squid.conf"
  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/cachemgr.conf" "${SQUID_CONFIG_DIR}/cachemgr.conf"
  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/errorpage.css" "${SQUID_CONFIG_DIR}/errorpage.css"
  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/mime.conf" "${SQUID_CONFIG_DIR}/mime.conf"

  #####################
  # for HTTPS
  #####################
  openssl genrsa -out "${SQUID_CONFIG_DIR}/ssl/squid.key" 2048
  openssl req -new -key "${SQUID_CONFIG_DIR}/ssl/squid.key" -out "${SQUID_CONFIG_DIR}/ssl/squid.csr" -subj '/C=XX/ST=XX/L=squid/O=squid/CN=squid'
  openssl x509 -req -days 3650 -in "${SQUID_CONFIG_DIR}/ssl/squid.csr" -signkey "${SQUID_CONFIG_DIR}/ssl/squid.key" -out "${SQUID_CONFIG_DIR}/ssl/squid.crt"
  cat "${SQUID_CONFIG_DIR}/ssl/squid.key" "${SQUID_CONFIG_DIR}/ssl/squid.crt" | sudo tee "${SQUID_CONFIG_DIR}/ssl/squid.pem"

  mkdir -p "${SQUID_LOGS_DIR}" "${SQUID_CACHE_DIR}"
  chown -R nobody:nogroup "${SQUID_LOGS_DIR}" "${SQUID_CACHE_DIR}" "${SQUID_CONFIG_DIR}"
}

function configure_iptables(){

  ###############################################################
  # firewall or basically iptables
  ###############################################################
  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/iptables-docker.conf" /etc/iptables.conf
  cp "${SUB_FOLDER}/flavors/squid_auto/startup_configs/iptables-rules" /etc/network/if-up.d/iptables-rules

  chown root: /etc/network/if-up.d/iptables-rules
  chmod 0755 /etc/network/if-up.d/iptables-rules

  # Check if OS is Amazon Linux 2023
  if grep -q "Amazon Linux 2023" /etc/os-release; then
    echo "OS is Amazon Linux 2023."

    # Check if firewalld is installed
    if systemctl list-units --type=service | grep -q firewalld; then
      echo "Disabling and stopping firewalld..."
      sudo systemctl disable firewalld --now
      echo "firewalld has been disabled and stopped."
    else
      echo "firewalld service not found."
    fi
  else
    echo "This system is not running Amazon Linux 2023."
  fi

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

if ( docker inspect squid -f '{{.State}}' > /dev/null 2>&1 );
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

  chmod +x /etc/squid_boot.sh
  chmod +x /etc/systemd/system/squid_boot.service
  systemctl enable squid_boot

  # Copy the updatewhitelist.sh script to the home directory
  require_file "${UPDATEWHITELIST_SCRIPT_FILE}"
  cp "${UPDATEWHITELIST_SCRIPT_FILE}" "${HOME_FOLDER}/updatewhitelist.sh"
  chmod +x "${HOME_FOLDER}/updatewhitelist.sh"

  require_file "${HEALTHCHECK_SCRIPT_FILE}"
  cp "${HEALTHCHECK_SCRIPT_FILE}" "${HOME_FOLDER}/healthcheck.sh"
  chmod +x "${HOME_FOLDER}/healthcheck.sh"

  crontab -l > crontab_file || true
  echo "*/15 * * * * ${HOME_FOLDER}/updatewhitelist.sh >/dev/null 2>&1" >> crontab_file
  echo "*/1 * * * * ${HOME_FOLDER}/healthcheck.sh >/dev/null 2>&1" >> crontab_file
  crontab crontab_file

  cat > /etc/cron.daily/squid <<EOF
#!/bin/bash
$(command -v docker) exec squid squid -k rotate
EOF

  chmod +x /etc/cron.daily/squid
}

function install_awslogs {

  ###############################################################
  # download and install awslogs
  ###############################################################
  if [[ $DISTRO == "Ubuntu" ]]; then
    wget "${AWSLOGS_DOWNLOAD_URL}" -O amazon-cloudwatch-agent.deb
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
                                                "log_group_name": "${CWL_GROUP:-}",
                                                "log_stream_name": "http_proxy-auth-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "LOCAL"
                                        },
                                        {
                                                "file_path": "${SQUID_LOGS_DIR}/access.log*",
                                                "log_group_name": "${CWL_GROUP:-}",
                                                "log_stream_name": "http_proxy-squid_access-$(${HOSTNAME})-${ip1}_${ip2}_${ip3}_${ip4}"
                                        },
                                        {
                                                "file_path": "/var/log/syslog",
                                                "log_group_name": "${CWL_GROUP:-}",
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

  if [[ -n "${CWL_GROUP:-}" ]]; then
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
    systemctl enable amazon-cloudwatch-agent.service
    systemctl start amazon-cloudwatch-agent.service
  fi
}

function set_user() {
  if [[ -z "${1:-}" ]]; then
    exit 1
  fi

  local username="${1}"

  useradd -m -s /bin/bash "${username}"
  mkdir -m 700 "/home/${username}/.ssh"
  cp -r "${HOME_FOLDER}/cloud-automation" "/home/${username}"

  require_file "${SSH_USER_KEYS_FILE}"

  cp "${SSH_USER_KEYS_FILE}" "/home/${username}/.ssh/authorized_keys"
  chown -R "${username}." "/home/${username}"
  chmod 600 "/home/${username}/.ssh/authorized_keys"
}

function init(){
  install_basics
  prepare_external_files
  set_admin_authorized_keys
  install_docker
  set_squid_config
  configure_iptables
  set_boot_configuration
  set_user sftpuser
  install_awslogs
}

function main(){
  init
  # If we don't restart the service, iptables might not load properly sometimes
  systemctl restart docker
  $(command -v docker) run --name squid --network=host -d \
      --volume "${SQUID_LOGS_DIR}:${SQUID_LOGS_DIR}" \
      --volume "${SQUID_PID_DIR}:${SQUID_PID_DIR}" \
      --volume "${SQUID_CACHE_DIR}:${SQUID_CACHE_DIR}" \
      --volume "${SQUID_CONFIG_DIR}:${SQUID_CONFIG_DIR}:ro" \
      "quay.io/cdis/squid:${SQUID_IMAGE_TAG}"

  aws ec2 modify-instance-attribute --no-source-dest-check --instance-id "$EC2_INSTANCE_ID" --region "$REGION"

  while true; do
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