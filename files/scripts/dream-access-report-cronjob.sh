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

echo "Setting up..."
dataFolder="$(mktemp -d -p "$XDG_RUNTIME_DIR" 'tempDreamReportDataFolder_XXXXXX')"
dateTime="$(date '+%Y-%m-%d_%H:%M')"
destFolder="$HOME/Dream_access_reports"
if [[ ! -e $destFolder ]]; then
  mkdir $destFolder
fi
fileName="Dream_access_report_$dateTime.tsv"
dreamTeamID=$(g3kubectl get secrets/fence-config -o json | jq -r '.data["fence-config.yaml"]' | base64 --decode | yq .DREAM_CHALLENGE_TEAM | tr -d '\\"')

logInterval=7
if [ "$1" != "" ]; then
  if ! [[ $1 =~ '^[0-9]+$' ]] ; then
    echo "Input argument is not a number, using default value '$logInterval' days"
  else
    logInterval=$1
    echo "Changing logInterval value to '$logInterval' days"
  fi
else
  echo "logInterval value is '$logInterval' days"
fi
echo "Done!"

echo "Generating user audit log..."
gen3 psql fence -A -t -o "$dataFolder/user.json" -c "SELECT json_agg(t) FROM (SELECT * FROM user_audit_logs WHERE timestamp > CURRENT_DATE - INTERVAL '$logInterval' DAY) t;"
echo "Done!"
echo "Generating cert audit log..."
gen3 psql fence -A -t -o "$dataFolder/cert.json" -c "SELECT json_agg(t) FROM (SELECT * FROM cert_audit_logs WHERE timestamp > CURRENT_DATE - INTERVAL '$logInterval' DAY) t;"
echo "Done!"
echo "Generating report TSV..."
python3 $HOME/cloud-automation/files/scripts/dream-access-report.py -t "$dreamTeamID" -u "$dataFolder/user.json" -c "$dataFolder/cert.json" -o "$destFolder/$fileName"
echo "All done!"

cd /tmp
/bin/rm -rf "${dataFolder}"