#
# Here for legacy reasons - prefer to source gen3setup.sh directly
#
g3kScriptDir="$(dirname -- "${BASH_SOURCE:-$0}")"
export GEN3_HOME="${GEN3_HOME:-$(dirname "$g3kScriptDir")}"

source "${GEN3_HOME}/gen3/gen3setup.sh"
