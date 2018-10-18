#
# Little helper to run gen3 and g3kubectl commands in a loop
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"


gen3_watch() {
  local command
  command="gen3"
  if [[ $# -lt 1 ]]; then
    return 0
  fi
  if [[ "$1" == "kubectl" || "$1" == "g3kubectl" ]]; then
    command="g3kubectl"
    shift
  elif [[ "$1" == "gen3" ]]; then
    shift
  fi
  while true; do
    "$command" "$@"
    sleep 4
    echo -e "\n\n"
  done
}

gen3_watch "$@"
