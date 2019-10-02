#!/bin/bash
#
# Save daily reports to the commons dashboard.
# Run as cron job in commons@adminvm user account
#
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# vpc_name=YOUR-VPC-NAME
# KUBECONFIG=path/to/kubeconfig
# 3   3   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/reports-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/reports-cronjob.sh "vpc=$vpc_name"; else echo "no reports-cronjob.sh"; fi) > $HOME/reports-cronjob.log 2>&1

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
Use: bash ./reports-cronjob.sh vpc=YOUR_VPC_NAME
EOM
}


# main -----------------------

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

if [[ $# -lt 1 || ! "$1" =~ ^vpc=.+$ ]]; then
  echo "ERROR: first argument must be `vpc=YOUR-VPC-NAME`"
  help
  exit 1
fi

dataFolder="$(mktemp -d -p "$XDG_RUNTIME_DIR" 'reportsFolder_XXXXXX')"
dateTime="$(date --date 'yesterday 00:00' +%Y%m%d)"
destFolder="reports/$(date --date 'yesterday 00:00' +%Y)/$(date --date 'yesterday 00:00' +%m)"
cd "$dataFolder"
gen3 logs history rtimes start='yesterday 00:00' end='today 00:00' "$@" | tee "rtimes-${dateTime}.json" 
gen3 logs history codes start='yesterday 00:00' end='today 00:00' "$@" | tee "codes-${dateTime}.json" 
gen3 logs history users start='yesterday 00:00' end='today 00:00' "$@" | tee "users-${dateTime}.json" 

csvToJson="$(cat - <<EOM
BEGIN {
  prefix="";
  print "{ \"data\": [";
};

(\$0 ~ /,/) {
  print prefix "[\"" \$1 "\"," \$2 "]"; prefix="," 
};

END { 
  print "] }"
};
EOM
)"

gen3 psql fence -c 'COPY (SELECT name, COUNT(*) FROM project, access_privilege ap WHERE ap.project_id=project.id GROUP BY name ORDER BY name) TO STDOUT WITH (FORMAT csv)' | \
  awk -F , "$csvToJson" | \
  jq -r . | \
  tee "projects-${dateTime}.json"

for name in "rtimes-${dateTime}.json" "codes-${dateTime}.json" "users-${dateTime}.json" "projects-${dateTime}.json"; do
  gen3 dashboard publish secure "./$name" "${destFolder}/$name"
done
cd /tmp
/bin/rm -rf "${dataFolder}"
