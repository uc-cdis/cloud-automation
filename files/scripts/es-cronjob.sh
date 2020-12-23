#!/bin/bash
#
# Save daily logs aggregations, and delete old indices.
# Run as cron job in qaplanetv1@cdistest.csoc or other selected user accounts:
#
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 2   2   *   *   *    (if [ -f $HOME/cloud-automation/files/scripts/es-cronjob.sh ]; then bash $HOME/cloud-automation/files/scripts/es-cronjob.sh; else echo "no es-cronjob.sh"; fi) > $HOME/es-cronjob.log 2>&1

export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"

if ! [[ -d "$GEN3_HOME" ]]; then
  echo "ERROR: this does not look like a gen3 environment - check $GEN3_HOME and $KUBECONFIG"
  exit 1
fi

PATH="${PATH}:/usr/local/bin"

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

source "${GEN3_HOME}/gen3/gen3setup.sh"
gen3 logs save daily

# save ubh saves a 12 hour window - window start is the argument
gen3 logs save ubh '-24 hours'
gen3 logs save ubh '-12 hours'

# Delete indices older than 3 weeks
gen3_retry gen3 logs curl200 "*-w$(date -d '1 week ago' +%U)" -X DELETE

# re-create indices
URL_ROOT="https://kibana.planx-pla.net"
curl "${URL_ROOT}/_cat/indices?v" | awk -F' ' '{print $3}' | awk -F'-' '{print $1}' | sort -u | while read -r prefix ; do
  res=$(curl "${URL_ROOT}/.kibana/index-pattern/${prefix}-*")
  found=$(echo $res | jq '.found')
  if [ $found == "true" ]; then
    timeFieldName=$(echo $res | jq '._source.timeFieldName')
    curl -XDELETE "${URL_ROOT}/.kibana/index-pattern/${prefix}-*"
    curl "${URL_ROOT}/.kibana/index-pattern/${prefix}-*/_create"\
    -H "Content-Type: application/json"\
    -H "Accept: application/json, text/plain, */*"\
    -H "kbn-xsrf: $prefix-*"\
    --data-binary "{\"title\":\"${prefix}-*\",\"timeFieldName\":$timeFieldName}" -w "\n"
  fi
done
