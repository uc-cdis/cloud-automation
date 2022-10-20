source "$GEN3_HOME/gen3/lib/utils.sh"
gen3_load "gen3/lib/terraform"

cd "$GEN3_WORKDIR"
if [[ ! -f plan.terraform ]]; then
  gen3_log_err "plan.terraform does not exist in workspace - run 'gen3 tfplan'"
  exit 1
fi

$GEN3_DRY_RUN && gen3_log_info "Running in DRY_RUN mode ..."

gen3_log_info "Running: terraform apply plan.terraform"
if [[ ! -z $USE_TF_1 ]]; then
  if ! ($GEN3_DRY_RUN || gen3_terraform -chdir="$GEN3_TFSCRIPT_FOLDER/" apply "${GEN3_WORKDIR}/plan.terraform"); then
    gen3_log_err "apply failed, bailing out"
    exit 1
  fi
else
  if ! ($GEN3_DRY_RUN || gen3_terraform  apply plan.terraform); then
    gen3_log_err "apply failed, bailing out"
    exit 1
  fi
fi
if [[ -d .git ]] && ! $GEN3_DRY_RUN; then
  git add .
  git commit -n -m 'pre-apply auto-commit' 1>&2
fi

dryRunFlag=""
if $GEN3_DRY_RUN; then
  dryRunFlag="--dryrun"
fi
if [[ "$GEN3_FLAVOR" == "AWS" ]]; then
  gen3_log_info "Backing up files to s3"
  for fileName in config.tfvars backend.tfvars README.md; do
    s3Path="s3://${GEN3_S3_BUCKET}/${GEN3_WORKSPACE}/$fileName"
    gen3_log_info "Backing up $fileName to $s3Path"
    gen3_aws_run aws s3 cp $dryRunFlag --sse AES256 "$fileName" "$s3Path"
  done
fi
