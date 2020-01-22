#!/bin/bash
#
# cluster-autoscaler allow a kubernetes cluste scale out or in depending on the 
# specification set in deployment. It'll talk to the ASG where the worker nodes are
# and send a signal to add or remove instances based upon requirements.
#
# Image version and other information can be found at
# https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler
#

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"

if [[ -n "$JENKINS_HOME" ]]; then
  echo "Jenkins skipping fluentd setup: $JENKINS_HOME"
  exit 0
fi


function get_kubernetes_server_version(){
  echo $(g3kubectl version -o json | jq -r '.serverVersion')
}

function get_kubernetes_server_version_numbers(){
  echo $(get_kubernetes_server_version |jq -r '.major + "." + .minor')
}

function get_autoscaler_version(){
  local k8s_version=$(get_kubernetes_server_version_numbers)
  local casv

  case ${k8s_version} in
    "1.17+")
      casv="1.17.0"
      ;;
    "1.16+")
      casv="1.16.3"
      ;;
    "1.15+")
      casv="1.15.4"
      ;;
    "1.14+")
      casv="1.14.7"
      ;;
    "1.13+")
      casv="1.13.9"
      ;;
    "1.12+")
      casv="1.12.8"
      ;;
  esac
  echo ${casv}
}


function deploy() {

  if (! g3kubectl --namespace=kube-system get deployment cluster-autoscaler > /dev/null 2>&1) || [[ "$FORCE" == true ]]; then
    if [ -z CAS_VERSION ];
    then
      cas_version=${CAS_VERSION}
    else
      cas_version=$(get_autoscaler_version) # cas stands for ClusterAutoScaler
    fi
    g3k_kv_filter "${GEN3_HOME}/kube/services/autoscaler/cluster-autoscaler-autodiscover.yaml" VPC_NAME "${vpc_name}" CAS_VERSION ${cas_Version} | g3kubectl "--namespace=kube-system" apply -f -
  else
    echo "kube-setup-autoscaler exiting - cluster-autoscaler already deployed, use --force to redeploy"
  fi

}


#if (! g3kubectl --namespace=kube-system get deployment cluster-autoscaler > /dev/null 2>&1) || [[ "$1" == "--force" ]]; then
  # k8s_version="$(g3kubectl version -o json |jq -r '.serverVersion.gitVersion')"
  # if [[ ${k8s_version} =~ -eks.*$ ]]; then tkv=${k8s_version//-eks*/}; k8s_version="${tkv}"; fi
  # k8s_version=$(get_kubernetes_server_version)
  # k8s_major=$(get_kubernetes_server_version |jq '.major')
  # k8s_minor=$(get_kubernetes_server_version |jq '.minor')
#  cas_version=$(get_autoscaler_version) # cas stands for ClusterAutoScaler

#  g3k_kv_filter "${GEN3_HOME}/kube/services/autoscaler/cluster-autoscaler-autodiscover.yaml" VPC_NAME "${vpc_name}" CAS_VERSION ${cas_Version} | g3kubectl "--namespace=kube-system" apply -f -
#else
#    echo "kube-setup-autoscaler exiting - cluster-autoscaler already deployed, use --force to redeploy"
#fi


function HELP(){
  echo "Usage: $SCRIPT [-v] <version> [-f] "
  echo "Options:"
  echo "No option is mandatory, however if you provide one of the following:"
  echo "        -v num       --version num       --create=num        Cluster autoscaler version number"
  echo "        -f           --force                                 Force and update if it is already installed"
}


OPTSPEC="hfv:-:"
while getopts "$OPTSPEC" optchar; do
  case "${optchar}" in
    -)
      case "${OPTARG}" in
        force)
          FORCE=true
          ;;
        version)
          CAS_VERSION="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        version=*)
          CAS_VERSION=${OPTARG#*=}
          ;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]; then
            echo "Unknown option --${OPTARG}" >&2
            HELP
            exit 2
          fi
          ;;
      esac;;
    f)
      FORCE=true
      ;;
    v)
      CAS_VERSION=${OPTARG}
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
