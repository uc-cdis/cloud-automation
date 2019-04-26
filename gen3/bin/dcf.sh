#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

AWS_INPUT_BUCKET="data-refresh-manifest"
AWS_OUTPUT_BUCKET="data-refresh-output"
GS_INPUT_BUCKET="replication-input"
GS_OUTPUT_BUCKET="datarefresh-log"

echo "Hello from dcf!"
command=$1
release=$2

# Activate google service account
if [ -f "$(gen3_secrets_folder)/g3auto/dcf_dataservice/googleCreds.json" ]; then
  gcloud auth activate-service-account --key-file=$(gen3_secrets_folder)/g3auto/dcf_dataservice/googleCreds.json
  export GOOGLE_APPLICATION_CREDENTIALS=$(gen3_secrets_folder)/g3auto/dcf_dataservice/googleCreds.json
fi

generate_aws_refresh_report() {
  manifest_type=$3
  manifest="$(aws s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F' ' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo "The $manifest_type manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$manifest" ]; then
    echo "Downloading the $manifest_type manifest from S3"
    aws s3 cp s3://$AWS_INPUT_BUCKET/$manifest $GEN3_CACHE_DIR/$manifest
  fi

  # Download the lattest log file
  refresh_log="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep GDC_full_sync_${manifest_type}_.*$release.*.txt$ | awk -F' ' '{print $4}')"
  if [ -z "$refresh_log" ]; then
    echo "fail to download $refresh_log log!!!"
    exit 1
  fi

  local_refresh_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_refresh_log)"
  echo $local_refresh_log
  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$refresh_log $local_refresh_log
  
  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_report --manifest $GEN3_CACHE_DIR/$manifest --log_file $local_refresh_log

  # Cleanup
  rm -f $local_refresh_log
}

validate_aws_refresh_report() {
  echo "Validate aws refresh"

  manifest_type=$3
  manifest="$(aws s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F' ' '{print $4}')"
  
  if [ -z "$manifest" ]; then
    echo "The $manifest_type manifest is missing"
    exit 1
  fi

  if [ ! -f "$GEN3_CACHE_DIR/$manifest" ]; then
    echo "Downloading the $manifest_type manifest from S3"
    aws s3 cp s3://$AWS_INPUT_BUCKET/$manifest $GEN3_CACHE_DIR/$manifest
  fi
  
  validation_log="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep validation.log | awk -F' ' '{print $4}')"

  if [ -z "${validation_log}" ]; then
    echo "The validation log does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  # Download the lattest log
  local_validation_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_validation_log)"
  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/validation.log $local_validation_log
  
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

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_report --manifest "/tmp/$manifest" --log_dir "$localLogDir/$manifest_type"

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

  validation_log="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep validation.log | awk -F' ' '{print $4}')"

  if [ -z "${validation_log}" ]; then
    echo "The validation log does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  # Download the lattest log
  local_validation_log="$(mktemp $XDG_RUNTIME_DIR/XXXXX_validation_log)"
  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/validation.log $local_validation_log

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_validate --manifest "/tmp/$manifest" --log_file "$local_validation_log"

  # Cleanup
  rm -f $local_validation_log

}

generate_isb_manifest() {
  manifest_type=$3
  manifest="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release.*_DCF.tsv$ | awk -F' ' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo """
    The augmented manifest does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$manifest ./
  echo "The manifest is saved at ./$manifest"

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
esac
