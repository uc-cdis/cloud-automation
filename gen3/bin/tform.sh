source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"
gen3_load "gen3/lib/terraform"


declare -a commandtList=()
if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  for flag in $@; do
    gen3_log_info "$flag"
    case "$flag" in
      --tf1)
        USE_TF_1="True"
        shift
        ;;
      *)
        commandList+=( "$1" )
        shift
    esac
  done
fi

if [[ ! -z $USE_TF_1 ]]; then
  gen3_terraform -chdir="$GEN3_TFSCRIPT_FOLDER/" "$@"
else
  gen3_terraform "$@"
fi
