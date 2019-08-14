#!/bin/bash
#
# Script to gather certain information about out kubernetes clusters and get a better understanding regarding compute resources utilized for these services.
#

export GEN3_HOME="${GEN3_HOME:-"$HOME/cloud-automation"}"

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
export KUBECONFIG="$HOME/${vpc_name}/kubeconfig"
PATH="${PATH}:/usr/local/bin"

#aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value]' --filter "Name=tag:Name,Values=*${vpc_name}"


function kube_facts() {

  eks_information="$( aws eks describe-cluster --name ${vpc_name} )"
  eks_version=$(echo -e ${eks_information} | jq -r .cluster.version)

  k8s_version=$(g3kubectl version  -o json)

}

function instances_facts() {

  local instances_name="eks-${vpc_name}"
  instance_list="$(aws ec2 describe-instances --filter "Name=tag:Name,Values=${instances_name}*")"
  instance_names="$(echo -e ${instance_list}| jq -r '.Reservations[].Instances[].Tags[] | select( .Key=="Name" ) | .Value')"

  total_instance_count="$(echo -e "${instance_names}" | wc -l)"

  jupyter_instances_count=$(echo -e "${instance_names}" | grep jupyter | wc -l)
  default_instances_count=$(echo -e "${instance_names}" | grep -v jupyter | wc -l)

  # echo -e ${instance_list} |jq -r '.Reservations[].Instances[] | select( .Tags[].Value=="'${instances_name}-jupyter'") | .Tags[] |select( .Key=="Name" )| .Value' |wc -l
  jupyter_instances="$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[] | select( .Tags[].Value=="'${instances_name}-jupyter'")')"
  default_instances="$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[] | select( .Tags[].Value=="'${instances_name}'")')"

  #jupyter_instance_type="$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[] | select( .Tags[].Value=="'${instances_name}-jupyter'") | .InstanceType' |sort |uniq)"
  jupyter_instance_type="$(echo -e "${jupyter_instances}" |jq .InstanceType | sort | uniq)"
  #default_instance_type="$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[] | select( .Tags[].Value=="'${instances_name}'") | .InstanceType' |sort |uniq)"
  default_instance_type="$(echo -e "${default_instances}" |jq .InstanceType | sort | uniq)"

  images_id=$(echo -e ${instance_list} | jq -r .Reservations[].Instances[].ImageId | sort |uniq)
}


function print_report_full() {

  echo
  echo ${vpc_name}
  echo -e "EKS version: ${eks_version}"
  echo -e "K8s version: Client-> $(echo -e ${k8s_version} | jq -r '.clientVersion| "\(.major).\(.minor)"') -- Server-> $(echo -e ${k8s_version} | jq -r '.serverVersion | "\(.major).\(.minor)"')"
  echo
  echo -e "Pool\t\tCount\t\tFlavor"
  echo -e "default\t\t${default_instances_count}\t\t$(echo ${default_instance_type})"
  echo -e "jupyter\t\t${jupyter_instances_count}\t\t$(echo ${jupyter_instance_type})"
  echo
  echo -e "AMIs: "${images_id}

}

## Let's do some admin work to find out the variables to be used here
BOLD='\e[1;31m'         # Bold Red
REV='\e[1;32m'       # Bold Green

#Help function
function HELP {
  gen3 help report-tool
  echo -e "${REV}Basic usage:${OFF} ${BOLD}$SCRIPT -r full ${OFF}"\\n
  echo -e "${REV}The following switches are recognized. $OFF "
  echo -e "${REV}-r --report ${OFF}  Print a report, valid types are 'full' only ${OFF}."
#  echo -e "Example: ${BOLD}$SCRIPT -d helloworld -p /opt/py27env/bin -v 2.7 ${OFF}"\\n
  exit 1
}


function main() {

  case "${1}" in
    "full")
      kube_facts
      instances_facts
      print_report_full
      ;;
    *)
      echo "Unknown value for the report"
      exit 2
      ;;
  esac
}

OPTSPEC="hr:-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        report)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          main ${val}
          #echo "Parsing option any: '--${OPTARG}', value: '${val}'" >&2;
          ;;
        report=*)
          val=${OPTARG#*=}
          opt=${OPTARG%=$val}
          #echo "Parsing option eq: '--${opt}', value: '${val}'" >&2
          main ${val}
          ;;
        help)
          HELP
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
      main ${OPTARG}
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
