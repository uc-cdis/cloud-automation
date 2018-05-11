#
# Run terraform output, and generate some derivate files
#

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

source "$GEN3_HOME/gen3/lib/utils.sh"
gen3_load "gen3/lib/terraform"

cd $GEN3_WORKDIR
gen3_terraform output -json > vpcdata.json
if [[ -z $1 ]]; then
  cat vpcdata.json
else
  jq -r ".${1}.value" < vpcdata.json
fi

