help() {
  cat - <<EOM
  gen3 tfplan:
    Run 'terraform plan' in the current workspace, and generate plan.output.  
    A typical command line is:
       terraform plan --var-file ./config.tfvars -var-file ../../aws.tfvars -out plan.terraform ~/Code/PlanX/cloud-automation/tf_files/aws/ 2>&1 | tee plan.log
EOM
  return 0
}

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

source "$GEN3_HOME/gen3/lib/common.sh"

cd $GEN3_WORKDIR
/bin/rm -f plan.terraform
echo "Running terraform plan --var-file ./config.tfvars -var-file ./aws_provider.tfvars -out plan.terraform $GEN3_HOME/tf_files/aws/"
terraform plan --var-file ./config.tfvars -var-file ./aws_provider.tfvars -out plan.terraform "$GEN3_HOME/tf_files/aws/" 2>&1 | tee plan.log
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
