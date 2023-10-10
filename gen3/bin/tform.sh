source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/terraform"


declare -a commandtList=()

if [[ ! -z $USE_TF_1 ]]; then
  gen3_terraform -chdir="$GEN3_TFSCRIPT_FOLDER/" "$@"
else
  gen3_terraform "$@"
fi
