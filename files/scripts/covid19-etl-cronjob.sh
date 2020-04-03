#!/bin/bash
#
# Runs daily COVID-19 Illinois Department for Public Health
# Run as cron job in covid19@adminvm user account
#
# USER=USER
# KUBECONFIG=path/to/kubeconfig
# 0   0   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/covid19-etl-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/covid19-etl-cronjob.sh; else echo "no codiv19-etl-cronjob.sh"; fi) > $HOME/covid19-etl-cronjob.log 2>&1

# setup --------------------

export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"

if ! [[ -d "$GEN3_HOME" ]]; then
  echo "ERROR: this does not look like a gen3 environment - check $GEN3_HOME and $KUBECONFIG"
  exit 1
fi

PATH="${PATH}:/usr/local/bin"

source "${GEN3_HOME}/gen3/gen3setup.sh"

# lib -------------------------

help() {
  cat - <<EOM
Use: bash ./covid19-etl-cronjob.sh
EOM
}


# main -----------------------

if [[ -z "$USER" ]]; then
  gen3_log_err "\$USER variable required"
  help
  exit 1
fi

if [[ -z "$JOB_NAME" ]]; then
  gen3_log_err "\$JOB_NAME variable required"
  help
  exit 1
fi

accessToken="$(gen3 api access-token $USER)"
gen3 job run covid19-etl ACCESS_TOKEN "$accessToken" JOB_NAME "$JOB_NAME"
