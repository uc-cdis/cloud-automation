#!/bin/bash




for i in $(kubectl get node -o name |cut -d/ -f2); do kubectl drain $i --ignore-daemonsets --delete-local-data; IDs=$(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --filters "Name=private-dns-name,Values=${i}"  --output text); aws ec2 stop-instances --instance-ids ${IDs}; sleep 500; done

function drain_node(){

  local instanceName=${1}
  gen3_log_info "Draining ${instanceName}"
  g3kubectl drain ${instanceName} --ignore-daemonsets --delete-local-data
}

function stop_instance() {

  # Let's get the instance id
  local instanceName=${1}
  local instanceId=$(aws ec2 describe-instances --query "Reservations[].Instances{}.InstanceId" --filter "Name=private-dns-name,Values=${instanceName}")

  if [ $? == 0 ];
  then
    gen3_log_info "Stopping instance ${instanceId}"
    aws ec2 stop-instances --instance-ids ${instanceId}
  else
    gen3_log_err "Couldn't find an instance with name ${instanceName}"
  fi
}



function main() {

  local instance=${1}

  if ! [ ${instance} == "ALL" ];
  then
    drain_node ${instance}
    stop_instance ${instance}
  else
    for i in $(kubectl get node -o name | cut -d/ -f2);
    do
      drain_node ${instance}
      stop_instance ${instance}
      sleep ${INTERVAL}
    done
  fi
}



OPTSPEC="ha:s:-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        single)
          INSTANCE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        single=*)
          INSTANCE=${OPTARG#*=}
          ;;
        all)
          INSTANCE="ALL"
          INTERVAL="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        all=*)
          INSTANCE="ALL"
          INTERVAL=${OPTARG#*=}
        help)
          help
          exit
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
            help
            exit 2
          fi
          ;;
      esac;;
    s)
      INSTANCE==${OPTARG}
      ;;
    a)
      INSTANCE="ALL"
      ;;
    h)
      help
      exit
      ;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${OPTSPEC:0:1}" = ":" ]; then
        echo "Non-option argument: '-${OPTARG}'" >&2
        help
        exit 2
      fi
      ;;
    esac
done



case ${INTERVAL} in
    ''|*[!0-9]*) 
      echo "bad interval, please correct it" 
      exit 
      ;;
    *) 
      main ${INSTANCE}
      ;;
esac


