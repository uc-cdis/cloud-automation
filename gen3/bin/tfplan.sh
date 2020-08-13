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
if [[ "$1" =~ ^-+destroy ]]; then
  destroyFlag="-destroy"
  shift
fi
declare -a targetList=()
while [[ "$1" =~ ^-+target ]]; do
  targetList+=( "$1" )
  shift
done

cd $GEN3_WORKDIR
/bin/rm -f plan.terraform

echo "Running terraform plan $destroyFlag "${targetList[@]}" --var-file ./config.tfvars out plan.terraform $GEN3_TFSCRIPT_FOLDER/"
gen3_terraform plan $destroyFlag "${targetList[@]}" --var-file ./config.tfvars -out plan.terraform "$GEN3_TFSCRIPT_FOLDER/" 2>&1 | tee plan.log
let exitCode=${PIPESTATUS[0]}
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
