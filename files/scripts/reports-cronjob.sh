#!/bin/bash
#
# Save daily reports to the commons dashboard.
# Run as cron job in commons@adminvm user account
#
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# vpc_name=YOUR-VPC-NAME
# ns_name=K8S_NAMESPACE (optional, defaults to "default")
# USER=USER
# KUBECONFIG=path/to/kubeconfig
# 3   3   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/reports-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/reports-cronjob.sh "vpc=$vpc_name" "ns_name=$ns_name"; else echo "no reports-cronjob.sh"; fi) > $HOME/reports-cronjob.log 2>&1

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
Use: bash ./reports-cronjob.sh vpc=YOUR_VPC_NAME [ns_name=K8S_NAMESPACE]
EOM
}


# main -----------------------

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

if [[ $# -lt 1 || ! "$1" =~ ^vpc=.+$ ]]; then
  gen3_log_err "first argument must be `vpc=YOUR-VPC-NAME`"
  help
  exit 1
fi

dataFolder="$(mktemp -d -p "$XDG_RUNTIME_DIR" 'reportsFolder_XXXXXX')"
dateTime="$(date --date 'yesterday 00:00' +%Y%m%d)"
destFolder="reports/$(date --date 'yesterday 00:00' +%Y)/$(date --date 'yesterday 00:00' +%m)"
cd "$dataFolder"
for service in all fence guppy indexd peregrine sheepdog; do
  for report in rtimes codes; do
      fileName="${report}-${service}-${dateTime}.json"
      if [[ "$service" == "all" ]]; then
        fileName="${report}-${dateTime}.json"
      fi
      gen3 logs history $report start='yesterday 00:00' end='today 00:00' proxy="$service" "$@" | tee "${fileName}"
  done
done
fileName="users-${dateTime}.json"
gen3 logs history users start='yesterday 00:00' end='today 00:00' "$@" | tee "${fileName}"

fileName="protocol-${dateTime}.json"
gen3 logs history protocol start='yesterday 00:00' end='today 00:00' "$@" | tee "${fileName}"

fileName="loginproviders-${dateTime}.json"
gen3 logs history loginproviders start='yesterday 00:00' end='today 00:00' "$@" | tee "${fileName}"

fileName="oidclogins-${dateTime}.json"
gen3 logs history oidclogins start='yesterday 00:00' end='today 00:00' "$@" | tee "${fileName}"

fileName="ga4ghrcodes-${dateTime}.json"
gen3 logs history ga4gs_rtimes start='yesterday 00:00' end='today 00:00' "$@" | tee "${fileName}"

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

for service in all fence guppy indexd peregrine sheepdog; do
  for report in rtimes codes; do
      fileName="${report}-${service}-${dateTime}.json"
      if [[ "$service" == "all" ]]; then
        fileName="${report}-${dateTime}.json"
      fi
      gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
  done
done
fileName="users-${dateTime}.json"
gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
fileName="projects-${dateTime}.json"
gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
fileName="protocol-${dateTime}.json"
gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
fileName="loginproviders-${dateTime}.json"
gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
fileName="ga4ghrcodes-${dateTime}.json"
gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
fileName="oidclogins-${dateTime}.json"
gen3 dashboard publish secure "./$fileName" "${destFolder}/$fileName"
cd /tmp
/bin/rm -rf "${dataFolder}"
