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

export vpc_name="$(grep 'vpc_name=' $HOME/.bashrc |cut -d\' -f2)"
export GEN3_HOME="$HOME/cloud-automation"
export KUBECONFIG="$HOME/${vpc_name}/kubeconfig"
PATH="${PATH}:/usr/local/bin"

echo ${vpc_name}
#aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value]' --filter "Name=tag:Name,Values=*${vpc_name}"


function gather_facts() {
  eks_information="$( aws eks describe-cluster --name ${vpc_name} )"
  k8s_version=$(echo -e ${eks_information} | jq -r .cluster.version)

  instance_list="$(aws ec2 describe-instances --filter "Name=tag:Name,Values=eks-*${vpc_name}*")"
  instance_names="$(echo -e ${instance_list}| jq -r '.Reservations[].Instances[].Tags[] | select( .Key=="Name" ) | .Value')"

  total_instance_count=$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[].Tags[] | select( .Key=="Name" ) | .Value' | wc -l)

  jupyter_instance_count=$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[].Tags[] | select( .Key=="Name" ) | .Value' |grep jupyter |wc -l)
  regular_instance_count=$(echo -e ${instance_list} |jq -r '.Reservations[].Instances[].Tags[] | select( .Key=="Name" ) | .Value' |grep -v jupyter | wc -l)

  images_id=$(echo -e ${instance_list} | jq -r .Reservations[].Instances[].ImageId | sort |uniq)
}


function print_report() {

  echo -e "EKS version: ${k8s_version}"
  echo
  echo
  echo -e "Pool\t\tCount\t\tAMI"
  echo -e "default\t\t${regular_instance_count}\t\t$(echo ${images_id})"
  echo -e "jupyter\t\t${jupyter_instance_count}\t\t$(echo ${images_id})"

}

function main() {
  gather_facts
  print_report
}

main
