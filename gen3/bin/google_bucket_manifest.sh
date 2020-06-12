#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

if ! hostname="$(g3kubectl get configmap manifest-global -o json | jq -r .data.hostname)"; then
    gen3_log_err "could not determine hostname from manifest-global - bailing out"
    return 1
fi

jobId=$(head /dev/urandom | tr -dc a-z0-9 | head -c 4 ; echo '')

prefix="${hostname//./-}-gcp-bucket-manifest-${jobId}"
saName=$(echo "${prefix}-sa" | head -c63)
temp_bucket="${prefix}_temp_bucket"


# function to create an job and returns a job id
#
# @param bucket: the input bucket
# @param service_account: the service account has access to the input bucket
#
gen3_create_google_dataflow() {
  if [[ $# -lt 1 ]]; then
    gen3_log_info "A input bucket"
    exit 1
  fi
  bucket=$1
  service_account=$2

  # use default service account if it is not provided
  if [[ "$service_account" == "" ]]; then
    service_account=$(gcloud config get-value account)
  fi

  echo $prefix

  local project=$(gcloud config get-value project)

  gsutil mb -c standard gs://"$temp_bucket"

  gen3 workon gcp-default ${prefix}__dataflow
  gen3 cd

  virtualenv venv
  source venv/bin/activate
  git clone https://github.com/uc-cdis/google-bucket-manifest && cd google-bucket-manifest && git checkout feat/bucket_manifest
  pip install -r requirements.txt
  
  python bucket_manifest_pipeline.py --runner DataflowRunner  --project "$project" --bucket "$bucket" --temp_location gs://"$temp_bucket"/temp  --template_location gs://"$temp_bucket"/templates/pipeline_template --region us-central1 --setup_file ./setup.py --service_account_email "${service_account}"
  #python bucket_manifest_pipeline.py --runner DataflowRunner  --project dcf-integration --bucket dcf-integration-test --temp_location gs://dcf-dataflow-bucket/temp  --template_location gs://dcf-dataflow-bucket/templates/pipe_line_example2.tpl --region us-central1 --setup_file ./setup.py --service_account_email giang-test-sa3@dcf-integration.iam.gserviceaccount.com
  gen3 cd

  # build google template
  cat << EOF > config.tfvars
project_id              = "${project}"
pubsub_topic_name        = "${prefix}-pubsub_topic_name"
pubsub_sub_name          = "${prefix}-pubsub_sub_name"
dataflow_name            = "${prefix}-dataflow_name"
template_gcs_path        = "gs://${temp_bucket}/templates/pipeline_template"
temp_gcs_location        = "gs://${temp_bucket}/temp"
service_account_email    = "${service_account}"
dataflow_zone            = "us-central1-a"
EOF

  gen3 tfplan 2>&1
  gen3 tfapply 2>&1
  if [[ $? != 0 ]]; then
    gen3_log_err "Unexpected error running gen3 tfapply."
    return 1
  fi
  sleep 10

  # gen3 gitops filter $HOME/cloud-automation/kube/services/jobs/bucket-manifest-job.yaml BUCKET $bucket JOB_QUEUE $job_queue JOB_DEFINITION $job_definition SQS $sqsUrl OUT_BUCKET $out_bucket | sed "s|sa-#SA_NAME_PLACEHOLDER#|$saName|g" | sed "s|bucket-manifest#PLACEHOLDER#|bucket-manifest-${jobId}|g" > ./bucket-manifest-${jobId}-job.yaml
  # gen3 job run ./bucket-manifest-${jobId}-job.yaml
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
  local search_dir="$HOME/.local/share/gen3/gcp-default"
  for entry in `ls $search_dir`; do
    if [[ $entry == *"__dataflow" ]]; then
      jobid=$(echo $entry | sed -n "s/^.*-\(\S*\)__dataflow$/\1/p")
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

  local search_dir="$HOME/.local/share/gen3/gcp-default"
  local is_jobid=0
  for entry in `ls $search_dir`; do
    if [[ $entry == *"__dataflow" ]]; then
      item=$(echo $entry | sed -n "s/^.*-\(\S*\)__dataflow$/\1/p")
      if [[ "$item" == "$jobId" ]]; then
        is_jobid=1
      fi
    fi
  done
  if [[ "$is_jobid" == 0 ]]; then
    gen3_log_err "job id does not exist"
    exit 1
  fi

  local prefix="${hostname//./-}-gcp-bucket-manifest-${jobId}"
  local temp_bucket="${prefix}_temp_bucket"

  gen3 workon gcp-default ${prefix}__dataflow
  gen3 cd
  gen3_load "gen3/lib/terraform"
  gen3_terraform destroy
  gen3 trash --apply

  gsutil rm -r gs://"${temp_bucket}"
}

command="$1"
shift
case "$command" in
  'create')
    gen3_create_google_dataflow "$@"
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
