#!/bin/bash
#
# Deploy the audit-service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


setup_database_and_config() {
  gen3_log_info "setting up audit-service..."

  if g3kubectl describe secret audit-g3auto > /dev/null 2>&1; then
    gen3_log_info "audit-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi
  # Setup config file that audit-service consumes
  if [[ ! -f "$secretsFolder/audit-service-config.yaml" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
    local secretsFolder="$(gen3_secrets_folder)/g3auto/audit"
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then    
      if ! gen3 db setup audit; then
        gen3_log_err "Failed setting up database for audit-service"
        return 1
      fi
    fi
    if [[ ! -f "$secretsFolder/dbcreds.json" ]]; then
      gen3_log_err "dbcreds not present in Gen3Secrets/"
      return 1
    fi
  
    cat - > "$secretsFolder/audit-service-config.yaml" <<EOM
####################
# SERVER           #
####################

# whether to enable debug logs
DEBUG: true

PULL_FROM_QUEUE: true
QUEUE_CONFIG:
  type: aws_sqs
  sqs_url: ${sqsUrl}
  aws_access_key_id:
  aws_secret_access_key:

####################
# DATABASE         #
####################

DB_HOST: $(jq -r .db_host < "$secretsFolder/dbcreds.json")
DB_USER: $(jq -r .db_username < "$secretsFolder/dbcreds.json")
DB_PASSWORD: $(jq -r .db_password < "$secretsFolder/dbcreds.json")
DB_DATABASE: $(jq -r .db_database < "$secretsFolder/dbcreds.json")
EOM
    # make it easy for nginx to get the Authorization header ...
    # echo -n "gateway:$password" | base64 > "$secretsFolder/base64Authz.txt"
  fi
  gen3 secrets sync 'setup audit-g3auto secrets'
}

setup_sqs() {
  gen3_log_info "setting up audit-service SQS"
  local sqsName="$(gen3 api safe-name audit-sqs)"
  local sqsInfo="$(gen3 sqs create-queue $sqsName)" || exit 1
  sqsUrl="$(jq -e -r '.["sqs-url"].value' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-url' from output: $sqsInfo"; exit 1; }
  gen3_log_info "audit-service SQS URL: $sqsUrl"
  local sqsSendMessageArn="$(jq -e -r '.["send-message-arn"].value' <<< "$sqsInfo")" || { echo "Cannot get 'send-message-arn' from output: $sqsInfo"; exit 1; }
  local sqsReceiveMessageArn="$(jq -e -r '.["receive-message-arn"].value' <<< "$sqsInfo")" || { echo "Cannot get 'receive-message-arn' from output: $sqsInfo"; exit 1; }

  local username
  gen3_log_info "Attaching send-message policy"
  username="$sqsName-sender-bot"
  gen3 awsuser create ${username}
  gen3 awsuser attach-policy ${sqsSendMessageArn} --username ${username}
  local user=$(gen3 secrets decode ${username}-g3auto awsusercreds.json)
  send_key_id=$(jq -r .id <<< $user)
  send_access_key=$(jq -r .secret <<< $user)

  gen3_log_info "Attaching receive-message policy"
  username="$sqsName-receiver-bot"
  gen3 awsuser attach-policy ${sqsReceiveMessageArn} --username ${username}
  local user=$(gen3 secrets decode ${username}-g3auto awsusercreds.json)
  send_key_id=$(jq -r .id <<< $user)
  send_access_key=$(jq -r .secret <<< $user)
}

if ! g3k_manifest_lookup '.versions["audit-service"]' 2> /dev/null; then
  gen3_log_info "kube-setup-audit-service exiting - audit-service not in manifest"
  exit 0
fi

# TODO if not exist sqs and iam
setup_sqs
# exit 1

if ! setup_database_and_config; then
  gen3_log_err "kube-setup-audit-service bailing out - database failed setup"
  exit 1
fi

gen3 roll audit-service
g3kubectl apply -f "${GEN3_HOME}/kube/services/audit-service/audit-service-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The audit-service has been deployed onto the kubernetes cluster"
