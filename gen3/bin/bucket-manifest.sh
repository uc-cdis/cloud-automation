#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! hostname="$(g3kubectl get configmap manifest-global -o json | jq -r .data.hostname)"; then
    gen3_log_err "could not determine hostname from manifest-global - bailing out of sower-jobs setup"
    return 1
fi

jobId=$(head /dev/urandom | tr -dc -Za-zA0-9 | head -c 4 ; echo '')

prefix="${hostname//./-}-bucket-manifest-${jobId}"
saName=$(echo "${prefix}-sa" | head -c63)


# function to create jo creates job and returns the job id
#
# @param bucket: the input bucket
# @param subnets: the subnets where the batch jobs live
# @param out_bucket: the bucket that stores the output manifest
#
gen3_create_aws_batch() {
  if [[ $# -lt 3 ]]; then
    gen3_log_info "The input bucket and subnets are required "
    exit 1
  fi
  bucket=$1
  subnets=$2
  out_bucket=$3
  echo $prefix
  local job_queue=$(echo "${prefix}_queue_job" | head -c63)
  local sqs_name=$(echo "${prefix}-sqs" | head -c63)
  local job_definition=$(echo "${prefix}-batch_job_definition" | head -c63)
  gen3 workon default ${prefix}__batch
  gen3 cd

  # Get aws credetial of fence_bot iam user
  local access_key=$(gen3 secrets decode fence-config fence-config.yaml | yq -r .AWS_CREDENTIALS.fence_bot.aws_access_key_id)
  local secret_key=$(gen3 secrets decode fence-config fence-config.yaml | yq -r .AWS_CREDENTIALS.fence_bot.aws_secret_access_key)

  cat << EOF > ${prefix}-job-definition.json
{
    "image": "quay.io/cdis/object_metadata:master",
    "memory": 256,
    "vcpus": 1,
    "environment": [
        {"name": "ACCESS_KEY_ID", "value": "${access_key}"},
        {"name": "SECRET_ACCESS_KEY", "value": "${secret_key}"},
        {"name": "BUCKET", "value": "${bucket}"},
        {"name": "SQS_NAME", "value": "${sqs_name}"}
    ]
}

EOF
  cat << EOF > config.tfvars
container_properties         = "./${prefix}-job-definition.json"
iam_instance_role            = "${prefix}-iam_ins_role"
iam_instance_profile_role    = "${prefix}-iam_ins_profile_role"
aws_batch_service_role       = "${prefix}-aws_service_role"
aws_batch_compute_environment_sg = "${prefix}-compute_env_sg"
role_description             = "${prefix}-role to run aws batch"
batch_job_definition_name    = "${prefix}-batch_job_definition"
compute_environment_name     = "${prefix}-compute-env"
subnets                      = ${subnets}
batch_job_queue_name         = "${job_queue}"
sqs_queue_name               = "${sqs_name}"
EOF

  cat << EOF > sa.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sqs:ListQueues",
            "Resource": "*"
        },
        {
             "Effect": "Allow",
             "Action": "sqs:*",
             "Resource": "arn:aws:sqs:us-east-1:707767160287:${sqs_name}"
        },
        {
             "Effect": "Allow",
             "Action": "batch:*",
             "Resource": "arn:aws:batch:us-east-1:707767160287:job-definition/${job_definition}"
        },
        {
             "Effect": "Allow",
             "Action": "batch:*",
             "Resource":"arn:aws:batch:us-east-1:707767160287:job-queue/${job_queue}"
        }
    ]
}
EOF

  gen3 tfplan 2>&1
  
  gen3 tfapply 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "Unexpected error running gen3 tfapply."
    return 1
  fi
  sleep 10     

  # Create a service account for k8s job for submitting jobs and consuming sqs
  gen3 iam-serviceaccount -c $saName -p sa.json

  # Run k8s jobs to submitting jobs and consuming sqs
  local sqsUrl=$(aws sqs get-queue-url --queue-name $sqs_name | jq -r .QueueUrl)
  gen3 gitops filter $HOME/cloud-automation/kube/services/jobs/bucket-manifest-job.yaml BUCKET $bucket JOB_QUEUE $job_queue JOB_DEFINITION $job_definition SQS $sqsUrl OUT_BUCKET $out_bucket | sed "s|sa-#SA_NAME_PLACEHOLDER#|$saName|g" | sed "s|bucket-manifest#PLACEHOLDER#|bucket-manifest-${jobId}|g" > ./bucket-manifest-${jobId}-job.yaml
  gen3 job run ./bucket-manifest-${jobId}-job.yaml
  gen3_log_info "The job is started. Job ID: ${jobId}"

}

# function to check job status
#
# @param job-id
#
gen3_manifest_generating_status() {
  gen3_log_info "Please use kubectl logs -f bucket-manifest-{jobid}-xxx command"
}


# Show help
gen3_bucket_manifest_help() {
  gen3 help bucket-manifest
}

# function to list all jobs
gen3_bucket_manifest_list() {
  local search_dir="$HOME/.local/share/gen3/default"
  for entry in `ls $search_dir`; do
    if [[ $entry == *"__batch" ]]; then
      jobid=$(echo $entry | sed -n "s/^.*-\(\S*\)__batch$/\1/p")
      echo $jobid
    fi
  done
}

# tear down the infrastructure 
gen3_batch_cleanup() {
  if [[ $# -lt 1 ]]; then
    gen3_log_info "Need to provide a job-id "
    exit 1
  fi
  jobId=$1
  local prefix="${hostname//./-}-bucket-manifest-${jobId}"
  local saName=$(echo "${prefix}-sa" | head -c63)

  gen3 workon default ${prefix}__batch
  gen3 cd
  gen3_load "gen3/lib/terraform"
  gen3_terraform destroy
  gen3 trash --apply

  # Delete service acccount, role and policy attached to it
  role=$(g3kubectl describe serviceaccount $saName | grep Annotations | sed -n "s/^.*:role\/\(\S*\)$/\1/p")
  policyName=$(gen3_aws_run aws iam list-role-policies --role-name $role | jq -r .PolicyNames[0])
  gen3_aws_run aws iam delete-role-policy --role-name $role --policy-name $policyName
  gen3_aws_run aws iam delete-role --role-name $role
  g3kubectl delete serviceaccount $saName
}

command="$1"
shift
case "$command" in
  'create')
    gen3_create_aws_batch "$@"
    ;;
  'cleanup')
    gen3_batch_cleanup "$@"
    ;;
  'status')
    gen3_manifest_generating_status
    ;;
  'list' )
    gen3_bucket_manifest_list
    ;;
  'help')
    gen3_bucket_manifest_help "$@"
    ;;
  *)
    gen3_bucket_manifest_help
    ;;
esac
exit $?