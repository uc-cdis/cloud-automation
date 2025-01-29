#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/kube-setup-init"

AWS_INPUT_BUCKET="data-refresh-manifest"
AWS_OUTPUT_BUCKET="data-refresh-output"
AWS_DCF_PROFILE="data_refresh"
GS_INPUT_BUCKET="data-refresh-manifest"
GS_OUTPUT_BUCKET="dcf-prod"

echo "Hello from dcf!"
command=$1
release=$2

# Activate google service account
if [ -f "$(gen3_secrets_folder)/g3auto/dcf-dataservice/googleCreds.json" ]; then
  gcloud auth activate-service-account --key-file=$(gen3_secrets_folder)/g3auto/dcf-dataservice/googleCreds.json
  export GOOGLE_APPLICATION_CREDENTIALS=$(gen3_secrets_folder)/g3auto/dcf-dataservice/googleCreds.json
fi

generate_aws_refresh_report() {
  manifest_type=$3
  manifest="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F' ' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo "The $manifest_type manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$manifest" ]; then
    echo "Downloading the $manifest_type manifest from S3"
    aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_INPUT_BUCKET/$manifest $GEN3_CACHE_DIR/$manifest
  fi

  # Download the lattest log file
  refresh_log="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep GDC_full_sync_${manifest_type}_.*$release.*.txt$ | awk -F' ' '{print $4}')"
  if [ -z "$refresh_log" ]; then
    echo "fail to download $refresh_log log!!!"
    exit 1
  fi

  local_refresh_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_refresh_log)"
  echo $local_refresh_log
  aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$refresh_log $local_refresh_log
  
  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_report --manifest $GEN3_CACHE_DIR/$manifest --log_file $local_refresh_log

  # Cleanup
  rm -f $local_refresh_log
}

validate_aws_refresh_report() {
  echo "Validate aws refresh"

  manifest_type=$3
  manifest="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F' ' '{print $4}')"
  
  if [ -z "$manifest" ]; then
    echo "The $manifest_type manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$manifest" ]; then
    echo "Downloading the $manifest_type manifest from S3"
    aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_INPUT_BUCKET/$manifest $GEN3_CACHE_DIR/$manifest
  fi
  
  validation_log="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep validation.log | awk -F' ' '{print $4}')"

  if [ -z "${validation_log}" ]; then
    echo "The validation log does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  # Download the lattest log
  local_validation_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_validation_log)"
  aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_OUTPUT_BUCKET/$release/validation.log $local_validation_log
  
  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_validate --manifest $GEN3_CACHE_DIR/$manifest --log_file $local_validation_log

  #Cleanup
  rm -f $local_validation_log

}

generate_gs_refresh_report() {

  manifest_type=$3
  manifest="$(gsutil ls gs://$GS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release.*tsv | awk -F'/' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo "The $manifest_type manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$manifest" ]; then
    echo "Downloading the $manifest_type manifest from GS"
    gsutil cp gs://$GS_INPUT_BUCKET/$manifest $GEN3_CACHE_DIR/$manifest
  fi

  localLogDir="$(mktemp -d $XDG_RUNTIME_DIR/XXXXX_Log_dir)"
  echo $localLogDir

  gsutil -m cp -r gs://$GS_OUTPUT_BUCKET/$release/$manifest_type $localLogDir

  if [ ! -d "$localLogDir" ]; then
    echo "Fail to download logs for google $manifest_type data refresh"
    exit 1
  fi

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_report --manifest "$GEN3_CACHE_DIR/$manifest" --log_dir "$localLogDir/$manifest_type"

  # Cleanup
  rm -rf "$localLogDir/$manifest_type"

}

validate_gs_refresh_report() {

  manifest_type=$3
  manifest="$(gsutil ls gs://$GS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release.*tsv | awk -F'/' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo "The $manifest_type manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$manifest" ]; then
    echo "Downloading the $manifest_type manifest from GS"
    gsutil cp gs://$GS_INPUT_BUCKET/$manifest $GEN3_CACHE_DIR/$manifest
  fi

  validation_log="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep validation.log | awk -F' ' '{print $4}')"

  if [ -z "${validation_log}" ]; then
    echo "The validation log does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  # Download the lattest log
  local_validation_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_validation_log)"
  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/validation.log $local_validation_log

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_validate --manifest "$GEN3_CACHE_DIR/$manifest" --log_file "$local_validation_log"

  # Cleanup
  rm -f $local_validation_log

}

redaction_rp() {
  redact_manifest="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_obsolete_.*$release | awk -F' ' '{print $4}')"
  if [ -z "$redact_manifest" ]; then
    echo "The redaction manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$redact_manifest" ]; then
    echo "Downloading the redaction manifest from S3"
    aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_INPUT_BUCKET/$redact_manifest $GEN3_CACHE_DIR/$redact_manifest
  fi

  aws_log="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep aws_deletion_log.json | awk -F' ' '{print $4}')"
  gs_log="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep gs_deletion_log.json | awk -F' ' '{print $4}')"
  
  if [ -z "$aws_log" ]; then
    echo "Can not find the redaction aws log"
    exit 1
  fi
  if [ -z "$gs_log" ]; then
    echo "Can not find the redaction google log"
    exit 1
  fi

  # Download the lattest log
  local_aws_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_aws_log)"
  local_gs_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_gs_log)"

  aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$aws_log $local_aws_log
  aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$gs_log $local_gs_log

  python3 $GEN3_HOME/gen3/lib/dcf/redaction.py redact --manifest $GEN3_CACHE_DIR/$redact_manifest --aws_log $local_aws_log --gs_log $local_gs_log

  # Cleanup
  rm -f $local_aws_log
  rm -f $local_gs_log

}

generate_isb_manifest() {
  manifest_type=$3
  manifest="$(aws --profile $AWS_DCF_PROFILE s3 ls s3://$AWS_OUTPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release.*_DCF.tsv$ | awk -F' ' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo """
    The augmented manifest does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  aws --profile $AWS_DCF_PROFILE s3 cp s3://$AWS_OUTPUT_BUCKET/$manifest ./
  echo "The manifest is saved at ./$manifest"

}

create_gs_bucket() {
  bucket_name=$2
  phsid=$3
  public=$4

  echo "Start creating gs bucket ...."

  if [[ $public == "controlled" ]]; then
    # Adding a fallback to `poetry run fence-create` to cater to fence containers with amazon linux.
    g3kubectl exec -c fence $(get_pod fence) -- fence-create google-bucket-create --unique-name $bucket_name --storage-class MULTI_REGIONAL --public False --project-auth-id $phsid --access-logs-bucket dcf-logs || \
    g3kubectl exec -c fence $(get_pod fence) -- poetry run fence-create google-bucket-create --unique-name $bucket_name --storage-class MULTI_REGIONAL --public False --project-auth-id $phsid --access-logs-bucket dcf-logs

  elif [[ $public == "public" ]]; then
    # Adding a fallback to `poetry run fence-create` to cater to fence containers with amazon linux.
    g3kubectl exec -c fence $(get_pod fence) -- fence-create google-bucket-create --unique-name $bucket_name --storage-class MULTI_REGIONAL --public True --access-logs-bucket dcf-logs || \
    g3kubectl exec -c fence $(get_pod fence) -- poetry run fence-create google-bucket-create --unique-name $bucket_name --storage-class MULTI_REGIONAL --public True --access-logs-bucket dcf-logs
  else
    echo "Can not create the bucket. $public is not supported"
    exit 1
  fi

  # Activate dcf prod google service account
  if [ -f "$(gen3_secrets_folder)/g3auto/dcf-dataservice/dcf_prod_buckets_creds.json" ]; then
    gcloud auth activate-service-account --key-file=$(gen3_secrets_folder)/g3auto/dcf-dataservice/dcf_prod_buckets_creds.json
    export GOOGLE_APPLICATION_CREDENTIALS=$(gen3_secrets_folder)/g3auto/dcf-dataservice/dcf_prod_buckets_creds.json

    gsutil acl ch -u 415083718423-compute@developer.gserviceaccount.com:OWNER gs://$bucket_name
    gsutil acl ch -u data-replication-dcf-prod@dcf-prod.iam.gserviceaccount.com:OWNER gs://$bucket_name
    gsutil acl ch -u service-415083718423@dataflow-service-producer-prod.iam.gserviceaccount.com:OWNER gs://$bucket_name

  fi

  echo "Done"

}

case "$command" in
"aws-refresh")
  generate_aws_refresh_report "$@"
  ;;
"validate-aws-refresh")
  validate_aws_refresh_report "$@"
  ;;
"google-refresh")
  generate_gs_refresh_report "$@"
  ;;
"validate-google-refresh")
  validate_gs_refresh_report "$@"
  ;;
"generate-augmented-manifest")
  generate_isb_manifest "$@"
  ;;
"redaction")
  redaction_rp "$@"
  ;;
"create-google-bucket")
  create_gs_bucket "$@"
  ;;
esac
