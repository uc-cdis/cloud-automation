#!/bin/bash
#
# Clean jenkins disk and reboot every weekend
#
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# vpc_name=YOUR-VPC-NAME
# KUBECONFIG=path/to/kubeconfig
# 1   1   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/jenkins-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/jenkins-cronjob.sh go; else echo "no jenkins-cronjob.sh"; fi) > $HOME/jenkins-cronjob.log 2>&1

export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"

if [[ ! -d "$GEN3_HOME" ]]; then
  echo "ERROR: GEN3_HOME does not exist: $GEN3_HOME" 1>&2
  exit 1
fi
if [[ -z "$XDG_DATA_HOME" ]]; then
  export XDG_DATA_HOME="$HOME/.local/share"
fi
if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi
if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  export XDG_RUNTIME_DIR="/tmp/gen3-$USER-$$"
  mkdir -m 700 -p "$XDG_RUNTIME_DIR"
fi

source "${GEN3_HOME}/gen3/gen3setup.sh"

command="help"
if [[ $# -gt 0 && ("$1" == "go" || "$1" == "test") ]]; then
  command="$1"
  shift
fi

if [[ "$command" == "help" ]]; then
  (cat - <<EOM
  Use: base jenkins-cronjob.sh go|help|test
EOM
  ) 1>&2
  exit 0
fi

jpod="$(gen3 pod jenkins)"
if [[ -z "$jpod" && "$command" != "test" ]]; then
  gen3_log_info "exiting - it looks like jenkins is not running"
  exit 1
fi

if [[ "$command" == "test" ]]; then
  gen3_log_info "exiting test without touching jenkins pod: $jpod"
  exit 0
elif [[ "$command" == "go" ]]; then
  g3kubectl exec -c jenkins "$jpod" -- bash -c 'sudo /bin/rm -rf /tmp/* /var/jenkins_home/workspace/*'
  g3kubectl exec -c jenkins "$jpod" -- bash -c "sudo find /var/jenkins_home/jobs/ -name builds -type d -mtime +5 -prune -print -exec /bin/rm -rf '{}' ';'"
  gen3 roll jenkins
  aws sns publish --topic-arn arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic --message 'qaplanetv1 jenkins-cronjob complete'
fi
