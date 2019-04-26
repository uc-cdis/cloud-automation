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
if [ -f "${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/creds.json" ]; then
  gcloud auth activate-service-account --key-file=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/creds.json
  export GOOGLE_APPLICATION_CREDENTIALS=${WORKSPACE}/${vpc_name}/apis_configs/dcf_dataservice/creds.json
fi

generate_aws_refresh_report() {
  manifest_type=$3
  manifest="$(aws s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F' ' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo "fail to download $manifest_type manifest!!!"
    exit 1
  fi

  refresh_log=${manifest//.tsv/.txt}

  echo "$refresh_log"

  if [ ! -f "/tmp/$manifest" ]; then
    aws s3 cp s3://$AWS_INPUT_BUCKET/$manifest /tmp/$manifest
  fi

  if [ ! -f "/tmp/$refresh_log" ]; then
    aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$refresh_log /tmp/$refresh_log
  fi

  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_report --manifest /tmp/$manifest --log_file /tmp/$refresh_log

}

validate_aws_refresh_report() {
  echo "Validate aws refresh"

  manifest_type=$3
  manifest="$(aws s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F' ' '{print $4}')"
  
  if [ -z "$manifest" ]; then
    echo "fail to download $manifest_type manifest!!!"
    exit 1
  fi
  
  if [ ! -f "/tmp/$manifest" ]; then
    aws s3 cp s3://$AWS_INPUT_BUCKET/$manifest /tmp/$manifest
  fi
  
  echo "Finish downloading the $manifest_type manifest"
  
  validation_log="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep validation.log | awk -F' ' '{print $4}')"

  if [ -z "${validation_log}" ]; then
    echo "The validation log does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi

  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/validation.log /tmp/validation.log
  
  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_validate --manifest /tmp/$manifest --log_file /tmp/validation.log

}

generate_gs_refresh_report() {

  manifest_type=$3

  manifest="$(gsutil ls gs://$GS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release.*tsv | awk -F'/' '{print $4}')"
  
  if [ -z "$manifest" ]; then
    echo "fail to download $manifest_type manifest!!!"
    exit 1
  fi

  gsutil cp gs://$GS_INPUT_BUCKET/$manifest /tmp/$manifest

  echo "Finish downloading the $manifest_type manifest"

  if [ -d "/tmp/$manifest_type/" ]; then
    rm -r /tmp/$manifest_type/
  fi

  mkdir -p /tmp/manifest

  echo "gs://$GS_OUTPUT_BUCKET/$release/$manifest_type"
  gsutil -m cp -r gs://$GS_OUTPUT_BUCKET/$release/$manifest_type /tmp/manifest/

  if [ ! -d "/tmp/manifest/" ]; then
    echo "Fail to download logs for google $manifest_type data refresh"
    exit 1
  fi

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_report --manifest "/tmp/$manifest" --log_dir "/tmp/manifest/$manifest_type"

}

validate_gs_refresh_report() {

  manifest_type=$3
  manifest="$(gsutil ls gs://$GS_INPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release | awk -F'/' '{print $4}')"
  
  if [ -z "$manifest" ]; then
    echo "fail to download $manifest_type manifest!!!"
    exit 1
  fi

  gsutil cp gs://$GS_INPUT_BUCKET/$manifest /tmp/$manifest

  echo "Finish downloading the $manifest_type manifest"


  if [ -d "/tmp/$manifest_type/" ]; then
    rm -r /tmp/$manifest_type/
  fi

  if [ -f "/tmp/validation.log" ]; then
    rm  /tmp/validation.log
  fi

  validation_log="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET/$release/ | grep validation.log | awk -F' ' '{print $4}')"

  if [ -z "${validation_log}" ]; then
    echo "The validation log does not exist. Please run the validation script first
    as desribed in https://github.com/uc-cdis/cdis-wiki/blob/master/ops/Data-refresh.md
    """
    exit 1
  fi
  
  aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/validation.log /tmp/validation.log

  echo "/tmp/$manifest"

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_validate --manifest "/tmp/$manifest" --log_file "/tmp/validation.log"

}

generate_isb_manifest() {
  manifest_type=$3
  manifest="$(aws s3 ls s3://$AWS_OUTPUT_BUCKET | grep GDC_full_sync_${manifest_type}_.*$release.*_DCF.tsv$ | awk -F' ' '{print $4}')"

  if [ -z "$manifest" ]; then
    echo """
    The aumgmented manifest does not exist. Please run the validation script first
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
