help() {
  cat - <<EOM
  gen3 tfplan [--destroy]:
    Run 'terraform plan' in the current workspace, and generate plan.output.  
    A typical command line (under the hood) is:
       terraform plan --var-file ./config.tfvars -var-file ../../aws.tfvars -out plan.terraform ~/Code/PlanX/cloud-automation/tf_files/aws/commons 2>&1 | tee plan.log
    If '--destroy' is passed, then a destroy plan is generated.
    Execute a generated plan with 'gen3 tfapply'
EOM
  return 0
}

source "$GEN3_HOME/gen3/lib/utils.sh"
gen3_load "gen3/lib/terraform"

destroyFlag=""
declare -a targetList=()
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  for flag in $@; do
    gen3_log_info "$flag"
    case "$flag" in
      --destroy)
        destroyFlag="-destroy";
        shift
        ;;
      --target)
        shift
        targetList+=( "--target=$1" )
        shift
        ;;
      --target*)
        targetList+=( "$1" )
        shift
        ;;
      --tf1)
        USE_TF_1="True"
        shift
        ;;
    esac
  done
fi

cd $GEN3_WORKDIR
/bin/rm -f plan.terraform

if [[ ! -z $USE_TF_1 ]]; then
	echo Running terraform -chdir="$GEN3_TFSCRIPT_FOLDER/" plan $destroyFlag "${targetList[@]}" --var-file ./config.tfvars -out plan.terraform
	gen3_terraform -chdir="$GEN3_TFSCRIPT_FOLDER/" plan $destroyFlag "${targetList[@]}" --var-file="${GEN3_WORKDIR}/config.tfvars" -out="${GEN3_WORKDIR}/plan.terraform"  2>&1 | tee plan.log
else
	echo Running terraform plan $destroyFlag "${targetList[@]}" --var-file ./config.tfvars -out plan.terraform "$GEN3_TFSCRIPT_FOLDER/"
	gen3_terraform plan $destroyFlag "${targetList[@]}" --var-file="${GEN3_WORKDIR}/config.tfvars" -out="${GEN3_WORKDIR}/plan.terraform" $GEN3_TFSCRIPT_FOLDER 2>&1 | tee plan.log
fi

let exitCode="${PIPESTATUS[0]}"
if [[ $exitCode -ne 0 ]]; then
  echo -e "${RED_COLOR}non zero exit code from terraform plan: ${exitCode}${DEFAULT_COLOR}"
  exit $exitCode
fi

if ! grep 'No changes' plan.log; then
  cat - <<EOM

WARNING: applying this plan will change your infrastructure.
    Do not apply a plan that 'destroys' resources unless you know what you are doing.

EOM
fi
echo "Use 'gen3 tfapply' to apply this plan, and backup the configuration variables"


