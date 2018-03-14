#
# Replace the files in the current workspace with
# the files in S3 after backing up the local files.
#

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

help() {
  cat - <<EOM
  Backup and refresh the local workspace config files from S3 after backing up the local files.
  Supports dry run.
  Ex:
    gen3 workon profile vpc
    gen3 --dryrun refresh
EOM
  exit 0
}

source "$GEN3_HOME/gen3/lib/common.sh"

mkdir -p -m 0700 "$GEN3_WORKDIR/backups"

refresh_file() {
  local fileName
  local filePath
  local s3Path
  local fileMd5
  local fileBackup
  fileName=$1
  
  echo ""
  echo ""
  if [[ -z "$fileName" ]]; then
    echo "ERROR: refresh_file() with empty fileName?"
    return 1
  fi
  filePath="$GEN3_WORKDIR/$fileName"
  s3Path="s3://$GEN3_S3_BUCKET/$GEN3_WORKSPACE/$fileName"

  if [[ -f "$filePath" ]]; then
    # make a backup
    fileMd5=$($MD5  "$filePath" | awk '{ print $1 }')
    fileBackup="$GEN3_WORKDIR/backups/${fileName}.${fileMd5}"
    echo "Backing up $fileName to $fileBackup"
    $GEN3_DRY_RUN || cp $filePath "$fileBackup"
  fi
  echo "aws s3 cp $s3Path $filePath"
  if ! ($GEN3_DRY_RUN || aws s3 cp $s3Path $filePath); then
    echo "WARNING: failed to refresh $filePath from $s3Path"
    return 1
  fi
  if [[ ! -z "$fileBackup" ]]; then
    echo "diff -w $fileBackup $filePath"
    diff -w "$fileBackup" "$filePath"
  fi
  return 0
}

for fileName in config.tfvars backend.tfvars README.md; do
  refresh_file $fileName
done

echo "Running terraform init ..."
cd "$GEN3_WORKDIR"
terraform init --backend-config ./backend.tfvars "$GEN3_TFSCRIPT_FOLDER/"

exit 0
