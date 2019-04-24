#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#INPUT_BUCKET="data-refresh-manifest"
AWS_INPUT_BUCKET="giang816test"
AWS_OUTPUT_BUCKET="data-refresh-output"

GS_INPUT_BUCKET="replication-input"
#GS_INPUT_BUCKET="data-flow-code/input"
GS_OUTPUT_BUCKET="datarefresh-log"
#OUTPUT_BUCKET="data-flow-code"


TMP_DIR="/tmp"

echo "Hello from dcf!"
command="$1"
release="$2"

generate_aws_refresh_report() {
  active_manifest="$(aws s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_active_.*$release | awk -F' ' '{print $4}')"
  legacy_manifest="$(aws s3 ls s3://$AWS_INPUT_BUCKET | grep GDC_full_sync_legacy_.*$release | awk -F' ' '{print $4}')"

  if [ -z "$active_manifest" ]; then
    echo "fail to download active manifest!!!"
    exit 1
  fi

  if [ -z "$legacy_manifest" ]; then
    echo "fail to download legacy manifest!!!"
    exit 1
  fi

  active_refresh_log="$(echo $active_manifest | sed -e 's/tsv/txt/g')"
  legacy_refresh_log="$(echo $legacy_manifest | sed -e 's/tsv/txt/g')"

  echo "$active_copy_log"

  if [ ! -f "/tmp/$active_manifest" ]; then
    aws s3 cp s3://$AWS_INPUT_BUCKET/$active_manifest /tmp/$active_manifest
  fi

  if [ ! -f "/tmp/$legacy_manifest" ]; then
    aws s3 cp s3://$AWS_INPUT_BUCKET/$legacy_manifest /tmp/$legacy_manifest
  fi

  if [ ! -f "/tmp/$active_refresh_log" ]; then
    aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$active_refresh_log /tmp/$active_refresh_log
  fi

  if [ ! -f "/tmp/$legacy_refresh_log" ]; then
    aws s3 cp s3://$AWS_OUTPUT_BUCKET/$release/$legacy_refresh_log /tmp/$legacy_refresh_log
  fi

  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_report --manifest /tmp/$active_manifest --log_file /tmp/$active_refresh_log
  python3 $GEN3_HOME/gen3/lib/dcf/aws_refresh_report.py aws_refresh_report --manifest /tmp/$legacy_manifest --log_file /tmp/$legacy_refresh_log

}

generate_google_refresh_report() {

  active_manifest="$(gsutil ls gs://$GS_INPUT_BUCKET | grep GDC_full_sync_active_.*$release | awk -F'/' '{print $4}')"
  legacy_manifest="$(gsutil ls gs://$GS_INPUT_BUCKET | grep GDC_full_sync_legacy_.*$release | awk -F'/' '{print $4}')"

  rm -r /tmp/active/
  rm -r /tmp/legacy/

  gsutil cp -r gs://$GS_OUTPUT_BUCKET/$release/active /tmp/active/
  gsutil cp -r gs://$GS_OUTPUT_BUCKET/$release/legacy /tmp/legacy/

  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_report --manifest /tmp/$active_manifest --log_file /tmp/active/
  python3 $GEN3_HOME/gen3/lib/dcf/google_refresh_report.py google_refresh_report --manifest /tmp/$legacy_manifest --log_file /tmp/legacy/

}

case "$command" in
"aws-refresh")
  generate_aws_refresh_report "$@"
  ;;
"google-refresh")
  generate_google_refresh_report "$@"
  ;;
esac

