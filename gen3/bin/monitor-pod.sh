#!/bin/bash
#
#  kubescope is a tool that would let you monitor a pod more easily and in real time 
#

# Load the basics

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping fluentd setup: $JENKINS_HOME"
  exit 0
fi



if [ $# -eq 0 ];
then
  echo "please provide a pod to monitor"
  exit 1
fi


function deploy-KS() {
  local node
  local threshold=10
  local now=$(date +%s)
  local name="${1}-${now}"
  local what="${2}"
  local node="${3}"

  g3k_kv_filter "${GEN3_HOME}/kube/services/kubescope/kubescope-cli.yaml" MONITOR_NAME ${name} TO_MONITOR ${what} NODE ${node}  |  g3kubectl apply -f -
  sleep 2
  while [ ${threshold} -ge 0 ];
  do
    g3kubectl get pod ${name}
    if [ $? -eq 0 ];
    then
      local ready=$(g3kubectl get pod ${name} -o jsonpath='{.status.containerStatuses[].ready}')
      if [ "${ready}" == "true" ];
      then
        g3kubectl attach -it ${name}
        break;
      fi
    fi
    threshold=$(( threshold - 1 ))
    sleep 2
  done
}


echo "Reviewing provided arguments"


if ( g3kubectl get pod ${1} > /dev/null 2>&1); 
then
  pod=${1}
  name="$(echo ${pod} | egrep -o "^[a-z0-9]*\-[a-z0-9]*")-monitor"
  node=$(g3kubectl get pod ${pod} -o jsonpath="{.spec.nodeName}")
else
  pod=$(gen3 pod ${1})
  if [ $? -eq 0 ];
  then
    name="$(echo ${pod} | egrep -o "^[a-z0-9]*\-[a-z0-9]*")-monitor"
    node=$(g3kubectl get pod ${pod} -o jsonpath="{.spec.nodeName}")
    #podi=$(echo $pod | egrep -o "^[a-z0-9]*\-[a-z0-9]*")
#    deploy-KS $name $pod $node
  fi
fi

deploy-KS ${name} ${pod} ${node}
