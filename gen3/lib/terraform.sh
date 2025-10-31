#
# Helper script for 'gen3 workon' - see ../README.md and ../gen3setup.sh
# that other bin/ scripts can 'source'
#

gen3_load "gen3/lib/utils"
gen3_load "gen3/lib/aws"

AWS_VERSION=$(aws --version 2>&1 | awk '{ print $1 }' | sed 's@^.*/@@')
if ! semver_ge "$AWS_VERSION" "1.14.0"; then
  echo "ERROR: gen3 requires aws cli >= 1.14.0 - please update from ${AWS_VERSION}"
  echo "  see https://docs.aws.amazon.com/cli/latest/userguide/installing.html - "
  echo "  'sudo python -m pip install awscli --upgrade' or 'python -m pip install awscli --upgrade --user'"
  exit 1
fi

TERRAFORM_VERSION=$(terraform --version | head -1 | awk '{ print $2 }' | sed 's/^[^0-9]*//')
if ! semver_ge "$TERRAFORM_VERSION" "0.11.7"; then
  echo "ERROR: gen3 requires terraform >= 0.11.7 - please update from ${TERRAFORM_VERSION}"
  echo "  see https://www.terraform.io/downloads.html"
  echo "/bin/rm /usr/local/bin/terraform && gen3 kube-setup-workvm"
  exit 1
fi

if [[  -z "$GEN3_PROFILE" || \
       -z "$GEN3_WORKSPACE" || \
       -z "$GEN3_WORKDIR" || \
       -z "$GEN3_HOME" || \
       -z "$GEN3_FLAVOR" || \
       ("$GEN3_FLAVOR" == "AWS" && -z "$GEN3_S3_BUCKET") \
    ]]; then
  echo "Must define runtime environment: GEN3_PROFILE, GEN3_WORKSPACE, GEN3_WORKDIR, GEN3_HOME"
  exit 1
fi

#
# This folder holds secrets, so lock it down permissions wise ...
#
umask 0077

if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi

#check_terraform_module ${GEN3_TFSCRIPT_FOLDER}
#gen3_log_info  "terraform versionxx ${tversion}"

# Little string to prepend to info messages
DRY_RUN_STR=""
if $GEN3_DRY_RUN; then DRY_RUN_STR="--dryrun"; fi

#
# Little helper - runs terraform through gen3_aws_run if in
# an AWS project
#
gen3_terraform() {
  local tversion=$(check_terraform_module ${GEN3_TFSCRIPT_FOLDER})
  if [[ "$GEN3_FLAVOR" == "AWS" ]]; then
    cat - 1>&2 <<EOM
gen3_aws_run terraform${tversion} $@
EOM
    gen3_aws_run terraform${tversion} "$@"
  elif [[ "$GEN3_FLAVOR" == "ONPREM" ]]; then
    cat - 1>&2 <<EOM
ONPREM NOOP terraform${tversion} $@
EOM
  else
      cat - 1>&2 <<EOM
terraform $@
EOM
    terraform${tversion} "$@"
  fi
}


#
# To help us out with a smooth transition into terraform 12
# we have added a new helper to invoke the right version of thereof
#
#gen3_terraform12() {
#  gen3_log_info "terraform 12"
#  if [[ "$GEN3_FLAVOR" == "AWS" ]]; then
#    cat - 1>&2 <<EOM
#gen3_aws_run terraform12 $@
#EOM
#    gen3_aws_run terraform12 "$@"
#  elif [[ "$GEN3_FLAVOR" == "ONPREM" ]]; then
#    cat - 1>&2 <<EOM
#ONPREM NOOP terraform12 $@
#EOM
#  else
#      cat - 1>&2 <<EOM
#terraform12 $@
#EOM
#    terraform12 "$@"
#  fi
#}
