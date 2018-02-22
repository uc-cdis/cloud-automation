#!/bin/bash
#
# fluentd would allow log sending from pods to cloudwatch
#

set -e

vpc_name=${vpc_name:-$1}
if [ -z "${vpc_name}" ]; then
   echo "Usage: bash kube-setup-fluentd.sh vpc_name"
   exit 1
fi
if [ ! -d ~/"${vpc_name}" ]; then
  echo "~/${vpc_name} does not exist"
  exit 1
fi

cd ~/${vpc_name}
sed -i "s/LGN/${vpc_name}/g"  services/fluentd/fluentd.yaml
kubectl apply -f services/fluentd/fluentd.yaml
