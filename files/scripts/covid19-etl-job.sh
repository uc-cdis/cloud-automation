#!/bin/bash
#
# Runs daily COVID-19 ETLs
# Run as cron job in covid19@adminvm user account
#
# USER=<USER>
# S3_BUCKET=<S3_BUCKET>
# KUBECONFIG=path/to/kubeconfig
# 0   0   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/covid19-etl-job.sh ]; then JOB_NAME=<JOB_NAME> bash $HOME/cloud-automation/files/scripts/covid19-etl-job.sh; else echo "no codiv19-etl-job.sh"; fi) > $HOME/covid19-etl-$JOB_NAME-job.log 2>&1

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
Use: bash ./covid19-etl-job.sh
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

if [[ -z "$S3_BUCKET" ]]; then
  gen3_log_err "\$S3_BUCKET variable required"
  help
  exit 1
fi

SAFE_JOB_NAME=${JOB_NAME//_/-} # `_` to `-`

# default token life is 3600 sec. some jobs need the token to last longer.
# also skip access-token cache since jobs need fresh tokens
EXP=14400 # 4 hours
ACCESS_TOKEN="$(gen3 api access-token $USER $EXP true)"

# temporary file for the job
tempFile="$(mktemp "$XDG_RUNTIME_DIR/covid19-etl-$SAFE_JOB_NAME-job.yaml_XXXXXX")"

# populate the job variable and change it's name to reflect the ETL being run
gen3 gitops filter $HOME/cloud-automation/kube/services/jobs/covid19-etl-job.yaml ACCESS_TOKEN "$ACCESS_TOKEN" JOB_NAME "$JOB_NAME" S3_BUCKET "$S3_BUCKET" \
  | sed "s|#COVID19_JOB_NAME_PLACEHOLDER#|$SAFE_JOB_NAME|g" > "$tempFile"

gen3 job run "$tempFile"

# cleanup
rm "$tempFile"
