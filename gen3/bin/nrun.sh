source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# lib ---------------------

#
# Install node apps under ${GEN3_HOME}
#
function gen3_nrun_install() {
  if [[ ! -d "${GEN3_HOME}/node_modules/.bin" || "$1" == "--force" ]]; then
    (
      cd $GEN3_HOME
      npm ci
    )
  fi
  "${GEN3_HOME}/node_modules/.bin/elasticdump" "$@"
}

#
# gen3 nrun command 
#   is a shortcut for 
# gen3 arun ${GEN3_HOME}/node_modules/.bin/
#
function gen3_nrun_bin() {
  if [[ $# -lt 1 ]]; then
    gen3_log_err "nrun requires at least one argument"
    return 1
  fi
  local command
  command="${GEN3_HOME}/node_modules/.bin/$1"
  shift
  if [[ ! -e "$command" ]]; then
    gen3_nrun_install --force 1>&2
  else
    gen3_nrun_install 1>&2
  fi
  gen3 arun "$command" "$@"
}

# main --------------------

command="$1"
shift

case "$command" in
"install")
  gen3_nrun_install --force
  ;;
*)
  gen3_nrun_bin "$command" "$@"
  ;;
esac

