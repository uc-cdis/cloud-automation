#!/bin/bash
#
# Generate weekly access report for Dream cha
#
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# KUBECONFIG=path/to/kubeconfig
# 6   6   *   *   1    (if [ -f $HOME/cloud-automation/files/scripts/dream-access-report-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/dream-access-report-cronjob.sh; else echo "no dream-access-report-cronjob.sh"; fi) > $HOME/dream-access-report-cronjob.log 2>&1

export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"

if ! [[ -d "$GEN3_HOME" ]]; then
  echo "ERROR: this does not look like a gen3 environment - check $GEN3_HOME and $KUBECONFIG"
  exit 1
fi

PATH="${PATH}:/usr/local/bin"

source "${GEN3_HOME}/gen3/gen3setup.sh"

gen3_log_info "Setting up..."
dataFolder="$(mktemp -d -p "$XDG_RUNTIME_DIR" 'tempDreamReportDataFolder_XXXXXX')"
dateTime="$(date -u '+%Y%m%d_%H%M')"
destFolder="$HOME/Dream_access_reports"
if [[ ! -e $destFolder ]]; then
  mkdir $destFolder
fi
dreamTeamID=$(g3kubectl get secrets/fence-config -o json | jq -r '.data["fence-config.yaml"]' | base64 --decode | yq .DREAM_CHALLENGE_TEAM | tr -d '\\"')

logInterval=7
regexNum='^[0-9]+$'
if [ "$1" != "" ]; then
  if ! [[ $1 =~ $regexNum ]] ; then
    gen3_log_err "Input argument is not a number, using default value '$logInterval' days"
  else
    logInterval=$1
    gen3_log_info "Changing logInterval value to '$logInterval' days"
  fi
else
  gen3_log_info "logInterval value is '$logInterval' days"
fi
gen3_log_info "Done!"
startTime="$(date -u -d"$logInterval days ago" +%Y%m%d)"
fileName="Dream_access_report_${startTime}_to_$dateTime.tsv"

gen3_log_info "Generating user audit log..."
gen3 psql fence -A -t -o "$dataFolder/user.json" -c "SELECT json_agg(t) FROM (SELECT * FROM user_audit_logs WHERE timestamp > CURRENT_DATE - INTERVAL '$logInterval' DAY ORDER BY id ASC) t;" 1>&2
gen3_log_info "Done!"
gen3_log_info "Generating cert audit log..."
gen3 psql fence -A -t -o "$dataFolder/cert.json" -c "SELECT json_agg(t) FROM (SELECT * FROM cert_audit_logs WHERE timestamp > CURRENT_DATE - INTERVAL '$logInterval' DAY ORDER BY id ASC) t;" 1>&2
gen3_log_info "Done!"
gen3_log_info "Generating report TSV..."
python3 "$GEN3_HOME/files/scripts/braincommons/dream-access-report.py" -t "$dreamTeamID" -u "$dataFolder/user.json" -c "$dataFolder/cert.json" -o "$destFolder/$fileName" 1>&2
gen3_log_info "All done!"

cd /tmp
/bin/rm -rf "${dataFolder}"

# brain_custom_reports expects this to be the last line of output
echo "$destFolder/$fileName"
