#!/bin/bash
#
# Create and interact with AWS SQS queues.
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#---------- lib

#
# Print doc
#
gen3_sqs_help() {
  gen3 help sqs
}

#
# Get information about an SQS queue (URL, ARN, current number of messages)
#
# @sqsName
#
gen3_sqs_info() {
  local sqsName=$1
  shift || { gen3_log_err "Must provide 'sqsName' to 'gen3_sqs_info'"; return 1; }

  sqsInfo1=$(gen3_aws_run aws sqs get-queue-url --queue-name $sqsName)
  sqsUrl="$(jq -e -r '.["QueueUrl"]' <<< "$sqsInfo1")" || { echo "Cannot get 'QueueUrl' from output: $sqsInfo1"; return 1; }
  if [ -z "$sqsUrl" ]; then
    return
  fi

  sqsInfo2=$(gen3_aws_run aws sqs get-queue-attributes --queue-url $sqsUrl --attribute-names QueueArn ApproximateNumberOfMessages) || return 1
  sqsArn="$(jq -e -r '.["Attributes"].QueueArn' <<< "$sqsInfo2")" || { echo "Cannot get 'QueueArn' from output: $sqsInfo2"; return 1; }
  sqsNumberMsgs="$(jq -e -r '.["Attributes"].ApproximateNumberOfMessages' <<< "$sqsInfo2")" || { echo "Cannot get 'ApproximateNumberOfMessages' from output: $sqsInfo2"; return 1; }

  cat - > "sqs-info.json" <<EOM
{
    "QueueUrl": "${sqsUrl}",
    "QueueArn": "${sqsArn}",
    "ApproximateNumberOfMessages": "${sqsNumberMsgs}"
}
EOM
  cat sqs-info.json
}

#
# Create an SQS queue
#
# @sqsName
#
gen3_sqs_create_queue() {
  local serviceName=$1
  if ! shift || [[ -z "$serviceName" ]]; then
    gen3_log_err "Must provide 'serviceName' to 'gen3_sqs_create_queue'"
    return 1
  fi
  local sqsName="$(gen3 api safe-name $serviceName)"
  gen3_log_info "Creating SQS '$sqsName'"
  ( # subshell - do not pollute parent environment
    gen3 workon default ${sqsName}__sqs 1>&2
    gen3 cd 1>&2
    cat << EOF > config.tfvars
sqs_name="$sqsName"
slack_webhook="$(g3k_slack_webhook)"
EOF
    gen3 tfplan 1>&2 || return 1
    gen3 tfapply 1>&2 || return 1
    gen3 tfoutput
  )
}

#
# Create an SQS queue if it does not exist, and return its URL and ARN
#
# @sqsName
#
gen3_sqs_create_queue_if_not_exist() {
  local serviceName=$1
  local sqsName="$(gen3 api safe-name $serviceName)"
  if ! shift || [[ -z "$sqsName" ]]; then
    gen3_log_err "Must provide 'sqsName' to 'gen3_sqs_create_queue'"
    return 1
  fi

  # check if the queue already exists
  local sqsInfo="$(gen3_sqs_info $sqsName)" || exit 1
  sqsUrl="$(jq -e -r '.["QueueUrl"]' <<< "$sqsInfo")"
  sqsArn="$(jq -e -r '.["QueueArn"]' <<< "$sqsInfo")"
  if [ -n "$sqsUrl" ]; then
    gen3_log_info "The '$sqsName' SQS already exists"
  else
    # create the queue
    sqsInfo="$(gen3_sqs_create_queue $serviceName)" || exit 1
    sqsUrl="$(jq -e -r '.["sqs-url"].value' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-url' from output: $sqsInfo"; exit 1; }
    sqsArn="$(jq -e -r '.["sqs-arn"].value' <<< "$sqsInfo")" || { echo "Cannot get 'sqs-arn' from output: $sqsInfo"; exit 1; }
  fi

  cat - > "sqs-info.json" <<EOM
{
    "url": "${sqsUrl}",
    "arn": "${sqsArn}"
}
EOM
  cat sqs-info.json
}

#
# Create a policy to push messages to a queue, and attach it to a role
#
# @sqsArn
# @roleName
#
gen3_sqs_attach_sender_policy_to_role() {
  local sqsArn=$1
  local roleName=$2
  if ! shift || [[ -z "$sqsArn" ]]; then
    gen3_log_err "Must provide 'sqsArn' to 'gen3_sqs_attach_sender_policy'"
    return 1
  fi
  if ! shift || [[ -z "$roleName" ]]; then
    gen3_log_err "Must provide 'roleName' to 'gen3_sqs_attach_sender_policy'"
    return 1
  fi

  gen3_log_info "Creating send-message policy"
  cat - > "sqs-message-sender-policy.json" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sqs:SendMessage",
            "Resource": [
                "${sqsArn}"
            ]
        }
    ]
}
EOM
  policy=$(cat sqs-message-sender-policy.json)

  # create the policy; get its ARN
  local policyName="$(gen3 api safe-name audit-sqs-sender)" || return 1
  policyInfo=$(gen3_aws_run aws iam create-policy --policy-name $policyName --policy-document "$policy" --description "Send messages to SQS $sqsArn")
  if [ -n "$policyInfo" ]; then
    policyArn="$(jq -e -r '.["Policy"].Arn' <<< "$policyInfo")" || { echo "Cannot get 'Policy.Arn' from output: $policyInfo"; return 1; }
  else
    echo "Unable to create policy $policyName. Assuming it already exists and continuing"
    policyArn=$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)
  fi

  gen3_log_info "Attaching policy '${policyName}' to role '${roleName}'"
  gen3 awsrole attach-policy ${policyArn} --role-name ${roleName} || return 1
}

#
# Create a policy to pull messages from a queue, and attach it to a role
#
# @sqsArn
# @roleName
#
gen3_sqs_attach_receiver_policy_to_role() {
  local sqsArn=$1
  local roleName=$2
  if ! shift || [[ -z "$sqsArn" ]]; then
    gen3_log_err "Must provide 'sqsArn' to 'gen3_sqs_attach_receiver_policy_to_role'"
    return 1
  fi
  if ! shift || [[ -z "$roleName" ]]; then
    gen3_log_err "Must provide 'roleName' to 'gen3_sqs_attach_receiver_policy_to_role'"
    return 1
  fi

  gen3_log_info "Creating receive-message policy"
  cat - > "sqs-message-receiver-policy.json" <<EOM
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "sqs:ReceiveMessage",
              "sqs:GetQueueAttributes",
              "sqs:DeleteMessage"
            ],
            "Resource": [
                "${sqsArn}"
            ]
        }
    ]
}
EOM
  policy=$(cat sqs-message-receiver-policy.json)

  # create the policy; get its ARN
  local policyName="$(gen3 api safe-name audit-sqs-receiver)" || return 1
  policyInfo=$(gen3_aws_run aws iam create-policy --policy-name $policyName --policy-document "$policy" --description "Receive messages from SQS $sqsArn")
  if [ -n "$policyInfo" ]; then
    policyArn="$(jq -e -r '.["Policy"].Arn' <<< "$policyInfo")" || { echo "Cannot get 'Policy.Arn' from output: $policyInfo"; return 1; }
  else
    echo "Unable to create policy $policyName. Assuming it already exists and continuing"
    policyArn=$(gen3_aws_run aws iam list-policies --query "Policies[?PolicyName=='$policyName'].Arn" --output text)
  fi

  gen3_log_info "Attaching policy '${policyName}' to role '${roleName}'"
  gen3 awsrole attach-policy ${policyArn} --role-name ${roleName} || return 1
}

#---------- main

gen3_sqs() {
  command="$1"
  shift
  case "$command" in
    'info')
      gen3_sqs_info "$@"
      ;;
    'create-queue')
      gen3_sqs_create_queue "$@"
      ;;
    'create-queue-if-not-exist')
      gen3_sqs_create_queue_if_not_exist "$@"
      ;;
    'attach-sender-policy-to-role')
      gen3_sqs_attach_sender_policy_to_role "$@"
      ;;
    'attach-receiver-policy-to-role')
      gen3_sqs_attach_receiver_policy_to_role "$@"
      ;;
    *)
      gen3_sqs_help
      ;;
  esac
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_sqs "$@"
fi
