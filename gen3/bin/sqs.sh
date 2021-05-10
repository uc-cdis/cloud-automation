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
# Get information about an SQS queue
#
# @sqsName
#
gen3_sqs_info() {
  local sqsName=$1
  shift || { gen3_log_err "Must provide 'sqsName' to 'gen3_sqs_info'"; return 1; }
  gen3_aws_run aws sqs get-queue-url --queue-name $sqsName
}

#
# Create an SQS queue and 2 policies to push and pull from the queue
#
# @sqsName
#
gen3_sqs_create_queue() {
  local sqsName=$1
  if ! shift || [[ -z "$sqsName" ]]; then
    gen3_log_err "Must provide 'sqsName' to 'gen3_sqs_create_queue'"
    return 1
  fi
  gen3_log_info "Creating SQS '$sqsName'"
  ( # subshell - do not pollute parent environment
    gen3 workon default sqscreate__sqs 1>&2
    gen3 cd 1>&2
    cat << EOF > config.tfvars
sqs_name="$sqsName"
EOF
    gen3 tfplan 1>&2 || exit 1
    gen3 tfapply 1>&2 || exit 1
    gen3 tfoutput
  )
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
    *)
      gen3_sqs_help
      ;;
  esac
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  gen3_sqs "$@"
fi
