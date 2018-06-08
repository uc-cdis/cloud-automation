#!/bin/bash
#
# Little helper to backup the ~/ folder to S3
# Note: this file is sourced by kube-up-body.sh (and thus kube-up.sh)
# Note: you can use the already existing cloud-formation s3_bucket in kube-up.sh
#


set -e

# name with _ for legacy reasons - see kube_vars.sh.tpl and kube-up-body.sh
vpc_name="${vpc_name:-$1}"
s3_bucket="${s3_bucket:-$2}"

if [[ -z "$vpc_name" || -z "$s3_bucket" ]]; then
  echo "Must specify the S3 bucket name to save the backup to"
  echo "Note: use the 's3_bucket' in {vpc_name}_output/kube-up.sh"
  exit 1
fi
homeParent=$(dirname "$HOME")
homeBase=$(basename "$HOME")

if [[ -z "$homeParent" || -z "$homeBase" ]]; then
  echo "Error processing home directory: $HOME"
  exit 1
fi

saveDir="${XDG_RUNTIME_DIR:-/tmp}"
saveFile="${vpc_name}_provisioner_$homeBase_$(date +%Y%m%d).tar"
savePath="$saveDir/$saveFile"
tar -C "$homeParent" -cvJf "$savePath" "$homeBase"
s3Path="s3://${s3_bucket}/provisionerBackups/$saveFile"
echo "Copying $savePath to $s3Path"
aws s3 cp --sse AES256 "$savePath" "$s3Path"
