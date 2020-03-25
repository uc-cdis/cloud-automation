#!/bin/bash
#
# Runs daily COVID-19 John's Hopkins University data ETL
# Run as cron job in covid19@adminvm user account
#
# vpc_name=YOUR-VPC-NAME
# USER=USER
# 3   3   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/covid19-etl-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/covid19-etl-cronjob.sh; else echo "no reports-cronjob.sh"; fi) > $HOME/reports-cronjob.log 2>&1

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
Use: bash ./covid19-etl-cronjob vpc=YOUR_VPC_NAME
EOM
}


# main -----------------------

if [[ -z "$USER" ]]; then
  gen3_log_err "$$USER variable required"
fi

accessToken="$(gen3 api access_token $USER)"
gen3 job run covid19-etl ACCESS_TOKEN "$accessToken"
