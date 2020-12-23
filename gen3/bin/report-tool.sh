#!/bin/bash
#
# Script to gather certain information about out kubernetes clusters and get a better understanding regarding compute resources utilized for these services.
#

export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"
SCRIPT=$(basename ${BASH_SOURCE[0]})

if ! [[ -d "$GEN3_HOME" ]]; then
  echo "ERROR: this does not look like a gen3 environment - check $GEN3_HOME and $KUBECONFIG"
  exit 1
fi

if [[ -z "$USER" ]]; then
  export USER="$(basename "$HOME")"
fi

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

export vpc_name="$(grep 'vpc_name=' $HOME/.bashrc |cut -d\' -f2)"
export GEN3_HOME="$HOME/cloud-automation"
#export KUBECONFIG="$HOME/${vpc_name}/kubeconfig"
export KUBECONFIG="$(gen3_secrets_folder)/kubeconfig"
PATH="${PATH}:/usr/local/bin"

#aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value]' --filter "Name=tag:Name,Values=*${vpc_name}"


function kube_facts() {
  local k8s_version=$(g3kubectl version  -o json)
  echo "${k8s_version}"
}

function eks_facts() {

  local eks_information="$( aws eks describe-cluster --name ${vpc_name} )"
  local eks_version="$(echo -e ${eks_information} | jq -r .cluster.version)"
  echo "${eks_information}"
}

# Get the facts for the instances associated to the commons 
function instances_facts() {

  local blob='{"pool": [] }'
  local cluster_instances_name="eks-${vpc_name}"
  local instance_list="$(aws ec2 describe-instances --filter "Name=tag:Name,Values=${cluster_instances_name}*")"
  local instance_names="$(echo ${instance_list}| jq -r '.Reservations[].Instances[].Tags[] | select( .Key=="Name" ) | .Value')"
  local total_instance_count="$(echo "${instance_names}" | wc -l)"
  local pools=$(printf "%s\n" ${instance_names} | sort | uniq)

  for pool in ${pools};
  do
    local pool_instance_count=$(echo "${instance_names}" | grep -o ${pool} | wc -l)
    local pool_instances="$(echo ${instance_list} |jq -r '.Reservations[].Instances[] | select( .Tags[].Value=="'${pool}'" )')"
    local pool_instance_type="$(echo "${pool_instances}" |jq .InstanceType | sort | uniq |tr "\n" ",")"
    local pool_ami_id=$(echo ${instance_list} | jq '.Reservations[].Instances[] | select( .Tags[].Value=="'${pool}'" ) |.ImageId' | sort |uniq |tr "\n" ",")
#    pool_ami
    blob=$(echo ${blob} | jq '.pool |= (.+ [{"'${pool}'":{count:'${pool_instance_count}',type:['${pool_instance_type::-1}'],AMIs:['${pool_ami_id::-1}']}}])')
  done
  echo "${blob}"
#  exit

}

# print a full report in json format
function print_report_full_json() {

  echo -e "$(eks_facts)" "$(kube_facts)" "$(instances_facts)" |jq -s '.[0] * .[1] * .[2]'
  #echo $(instances_facts) | jq .
}

function print_report_full() {

  local eks_facts=$(eks_facts)
  local kube_facts=$(kube_facts)
  local instances_facts=$(instances_facts)

  local pool_size=$(echo ${instances_facts} |jq -r '.pool| length')

  echo
  echo ${vpc_name}
  echo -e "EKS version: $(echo -e ${eks_facts} | jq -r .cluster.version)"
  echo -e "K8s version: Client-> $(echo -e ${kube_facts} | jq -r '.clientVersion| "\(.major).\(.minor)"') -- Server-> $(echo -e ${kube_facts} | jq -r '.serverVersion | "\(.major).\(.minor)"')"
  echo
  #echo -e "Pool\t\t\t\tCount\t\tFlavor"
  local table_header="Pool Count Flavor"
  local table_content=""
  for (( i = 0; i < ${pool_size}; i++ ))
  do
    local pool_key="$(echo ${instances_facts} | jq -r '.pool['${i}']| keys[]')"
    local pool_count="$(echo ${instances_facts} | jq -r '.pool['${i}']."'${pool_key}'".count')"
    local pool_types="$(echo ${instances_facts} | jq -r '.pool['${i}']."'${pool_key}'".type[]')"
    table_content="${pool_key} ${pool_count} ${pool_types} ${table_content}"
  done
  local IFS=' '
  read -ra TABLE <<< "${table_header} ${table_content}"
  printf "%-30s%-10s%s\n" "${TABLE[@]}" 

  images_id=$(echo -e ${instances_facts} | jq -r '.pool[]| to_entries[] | "\(.value | .AMIs[])"' |sort |uniq|tr '\n' ' ')

  echo
  echo -e "AMIs: "${images_id}

}

## Let's do some admin work to find out the variables to be used here
BOLD='\e[1;31m'         # Bold Red
REV='\e[1;32m'       # Bold Green

#Help function
function HELP() {
  gen3 help report-tool
  echo -e "${REV}Basic usage:${OFF} ${BOLD}$SCRIPT -r full ${OFF}"\\n
  echo -e "${REV}The following switches are recognized. $OFF "
  echo -e "${REV}-r --report ${OFF}  Print a report, valid types are 'full' only ${OFF}."
  echo -e "${REV}-o --output ${OFF}  Output format, valid options are 'json' and 'plain', plain is set by default ${OFF}."
  echo -e "Example: ${BOLD}$SCRIPT -r full ${OFF}"\\n
  exit 1
}


function main() {

  case "${1}" in
    "full")
      case "${2}" in
        "plain")
          print_report_full
          ;;
        "json")
          print_report_full_json
          ;;
      esac
      #kube_facts
      #instances_facts
      #print_report_full_json
      #print_report_full
      ;;
    *)
      echo "Unknown value for the report"
      exit 2
      ;;
  esac
}

OPTSPEC="ho:r:-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        report)
          REPORT_TYPE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          #main ${val}
          #echo "Parsing option any: '--${OPTARG}', value: '${val}'" >&2;
          ;;
        report=*)
          REPORT_TYPE=${OPTARG#*=}
          #opt=${OPTARG%=$val}
          #echo "Parsing option eq: '--${opt}', value: '${val}'" >&2
          #main ${val}
          ;;
        output)
          OUTPUT="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        output=*)
          OUTPUT=${OPTARG#*=}
          ;;
        help)
          HELP
          exit
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
            HELP
            exit 2
          fi
          ;;
      esac;;
    r)
      #echo "Parsing option: '${OPTARG}'" >&2
      REPORT_TYPE=${OPTARG}
      #main ${OPTARG}
      ;;
    o)
      OUTPUT=${OPTARG}
      ;;
    h)
      HELP
      ;;
    *)
      if [ "$OPTERR" != 1 ] || [ "${OPTSPEC:0:1}" = ":" ]; then
        echo "Non-option argument: '-${OPTARG}'" >&2
        HELP
        exit 2
      fi
      ;;
    esac
done

if [ -z ${OUTPUT} ];
then 
  OUTPUT="plain"
fi

#echo "$OUTPUT - $REPORT_TYPE"
#exit
main ${REPORT_TYPE} ${OUTPUT}
