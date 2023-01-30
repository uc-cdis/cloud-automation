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
    "1.22+")
      casv="v1.22.2"
      ;;
    "1.21+")
      casv="v1.21.2"
      ;;
    "1.20+")
      casv="v1.20.0"
      ;;
    "1.19+")
      casv="v1.19.1"
      ;;
    "1.18+")
      casv="v1.18.3"
      ;;
    "1.17+")
      casv="v1.17.4"
      ;;
    "1.16+")
      casv="v1.16.7"
      ;;
    "1.15+")
      casv="v1.15.7"
      ;;
    "1.14+")
      casv="v1.14.8"
      ;;
    "1.13+")
      casv="v1.13.9"
      ;;
    "1.12+")
      casv="v1.12.8"
      ;;
  esac
  echo ${casv}
}


function deploy() {

  if (! g3kubectl --namespace=kube-system get deployment cluster-autoscaler > /dev/null 2>&1) || [[ "$FORCE" == true ]]; then
    if ! [ -z ${CAS_VERSION} ];
    then
      casv=${CAS_VERSION}
    else
      casv="$(get_autoscaler_version)" # cas stands for ClusterAutoScaler
    fi
    echo "Deploying cluster autoscaler ${casv} in ${vpc_name}"
    g3k_kv_filter "${GEN3_HOME}/kube/services/autoscaler/cluster-autoscaler-autodiscover.yaml" VPC_NAME "${vpc_name}" CAS_VERSION ${casv} | g3kubectl "--namespace=kube-system" apply -f -
  else
    echo "kube-setup-autoscaler exiting - cluster-autoscaler already deployed, use --force to redeploy"
  fi

}

function remove() {

  if ( g3kubectl --namespace=kube-system get deployment cluster-autoscaler > /dev/null 2>&1); then
    if ! [ -z ${CAS_VERSION} ];
    then
      casv=${CAS_VERSION}
    else
      casv="$(get_autoscaler_version)" # cas stands for ClusterAutoScaler
    fi
    echo "Removing cluster autoscaler ${casv} in ${vpc_name}"
    g3k_kv_filter "${GEN3_HOME}/kube/services/autoscaler/cluster-autoscaler-autodiscover.yaml" VPC_NAME "${vpc_name}" CAS_VERSION ${casv} | g3kubectl "--namespace=kube-system" delete -f -
  else
    echo "kube-setup-autoscaler exiting - cluster-autoscaler not deployed"
  fi

}


function HELP(){
  echo "Usage: $SCRIPT [-v] <version> [-f] [-r]"
  echo "Options:"
  echo "No option is mandatory, however you can provide the following:"
  echo "        -v num       --version num       --create=num        Cluster autoscaler version number"
  echo "        -f           --force                                 Force and update if it is already installed"
  echo "        -r           --remove                                remove deployment if already installed"
}

#echo $(get_autoscaler_version)

OPTSPEC="hfvr:-:"
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
        remove)
          remove
          exit 0
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
    r)
      remove
      exit 0
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

deploy