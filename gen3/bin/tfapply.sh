help() {
  cat - <<EOM
  gen3 tfapply:
    Run 'terraform apply' in the current workspace, and backup config.tfvars, backend.tfvars, and README.md.  
    A typical command line is:
       terraform apply plan.terraform
EOM
  return 0
}

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

source "$GEN3_HOME/gen3/lib/common.sh"

cd $GEN3_WORKDIR
if [[ ! -f plan.terraform ]]; then
  echo "plan.terraform does not exist in workspace - run 'gen3 tfplan'"
  exit 1
fi

$GEN3_DRY_RUN && "Running in DRY_RUN mode ..."
echo "Running: terraform apply plan.terraform"
if ! ($GEN3_DRY_RUN || terraform apply plan.terraform); then
  echo "apply failed, bailing out"
  exit 1
fi

echo "Backing up files to s3"
dryRunFlag=""
if $GEN3_DRY_RUN; then
  dryRunFlag="--dryrun"
fi
for fileName in config.tfvars backend.tfvars README.md; do
  s3Path="s3://${GEN3_S3_BUCKET}/${GEN3_WORKSPACE}/$fileName"
  echo "Backing up $fileName to $s3Path"
  aws s3 cp $dryRunFlag --sse AES256 "$fileName" "$s3Path"
done
