
#
# for tty service - see https://github.com/butlerx/wetty/blob/main/docs/downloading-files.md
#
function wetty-download() {
  echo "\033[5i"$(cat /dev/stdin | base64 -w 0)"\033[4i"
}

source <(kubectl completion bash)

export JENKINS_HOME=true
export GEN3_HOME="$HOME/cloud-automation"
export ESHOST="esproxy-service:9200"
source "${GEN3_HOME}/gen3/gen3setup.sh"
