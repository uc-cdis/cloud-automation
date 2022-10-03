#!/bin/bash
#
# Deploy the audit-service.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


setup_database_and_config() {
  gen3_log_info "setting up audit-service DB and config"

  if g3kubectl describe secret audit-g3auto > /dev/null 2>&1; then
    gen3_log_info "audit-g3auto secret already configured"
    return 0
  fi
  if [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
    gen3_log_err "skipping db setup in non-adminvm environment"
    return 0
  fi

  # Setup config file that audit-service consumes
  local secretsFolder="$(gen3_secrets_folder)/g3auto/audit"
  if [[ ! -f "$secretsFolder/audit-service-config.yaml" || ! -f "$secretsFolder/base64Authz.txt" ]]; then
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

    availability_zone=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone -s)
    region=$(echo ${availability_zone::-1})
  
    cat - > "$secretsFolder/audit-service-config.yaml" <<EOM
####################
# SERVER           #
####################

# whether to enable debug logs
DEBUG: true

PULL_FROM_QUEUE: true
QUEUE_CONFIG:
  type: aws_sqs
  aws_sqs_config:
    sqs_url: ${sqsUrl}
    region: ${region}

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

setup_audit_sqs() {
  local sqsName="$(gen3 api safe-name audit-sqs)"
  sqsInfo="$(gen3 sqs create-queue-if-not-exist $sqsName)" || exit 1
  sqsUrl="$(jq -e -r '.["url"]' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-url' from output: $sqsInfo"; exit 1; }
  sqsArn="$(jq -e -r '.["arn"]' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-arn' from output: $sqsInfo"; exit 1; }

  # audit-service can pull messages from the audit queue
  local saName="audit-service-sa"
  local roleName="$(gen3 api safe-name audit-sqs-receiver)" || exit 1
  gen3_log_info "setting up service account '$saName' with role '${roleName}'"
  if ! gen3 awsrole info "$roleName" > /dev/null; then # create role
    gen3 awsrole create "$roleName" "$saName" || exit 1
  fi
  gen3 sqs attach-receiver-policy-to-role $sqsArn $roleName || exit 1
}

gen3_log_info "setting up audit-service..."

if ! g3k_manifest_lookup '.versions["audit-service"]' 2> /dev/null; then
  gen3_log_info "kube-setup-audit-service exiting - audit-service not in manifest"
  exit 0
fi

g3kubectl create sa "audit-service-sa" > /dev/null 2>&1 || true

if ! [[ -n "$JENKINS_HOME" || ! -f "$(gen3_secrets_folder)/creds.json" ]]; then
  if ! setup_audit_sqs; then
    gen3_log_err "kube-setup-audit-service bailing out - failed to setup audit SQS"
    exit 1
  fi
fi

if ! setup_database_and_config; then
  gen3_log_err "kube-setup-audit-service bailing out - database/config failed setup"
  exit 1
fi

gen3 roll audit-service
g3kubectl apply -f "${GEN3_HOME}/kube/services/audit-service/audit-service-service.yaml"

if [[ -z "$GEN3_ROLL_ALL" ]]; then
  gen3 kube-setup-networkpolicy
  gen3 kube-setup-revproxy
fi

gen3_log_info "The audit-service has been deployed onto the kubernetes cluster"
