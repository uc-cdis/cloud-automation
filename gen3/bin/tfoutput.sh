#
# Run terraform output, and generate some derivate files
#

if [[ ! -f "$GEN3_HOME/gen3/lib/common.sh" ]]; then
  echo "ERROR: no $GEN3_HOME/gen3/lib/common.sh"
  exit 1
fi

help() {
  cat - <<EOM
  gen3 tfoutput [variable-name]:
    Run *terraform output* in the current workspace to log the current environment's output variables,
    and generate some supporting files.  
    A typical command line is:
       terraform output -json > vpcdata.json
EOM
  return 0
}

source "$GEN3_HOME/gen3/lib/common.sh"

cd $GEN3_WORKDIR
gen3_aws_run terraform output -json > vpcdata.json
if [[ -z $1 ]]; then
  cat vpcdata.json
else
  jq -r ".${1}.value" < vpcdata.json
fi

