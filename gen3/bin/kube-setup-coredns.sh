#!/bin/bash
# 
# With the introduction of k8s 1.11 (or mostly for our case on using EKS) coreDNS is 
# intended to replace kube-dns, therefore we should also move along with this.
#
# When you upgrade, the switch doesn't happen automatically. There are a few steps to follow
#
# https://docs.aws.amazon.com/eks/latest/userguide/coredns.html

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"


# 1. Add the {"eks.amazonaws.com/component": "kube-dns"} selector to the kube-dns deployment for your cluster. This prevents the two DNS deployments from competing for control of the same set of labels.

g3kubectl patch -n kube-system deployment/kube-dns --patch '{"spec":{"selector":{"matchLabels":{"eks.amazonaws.com/component":"kube-dns"}}}}' || true



# 2. Deploy CoreDNS to your cluster.

  # a. Set your cluster's DNS IP address to the DNS_CLUSTER_IP environment variable.

  DNS_CLUSTER_IP=$(g3kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')


  # b. Set your cluster's AWS Region to the REGION environment variable.
  # export REGION="us-west-2"
  # Assuming you are always running kubectl on a vm in the same Region as of your kubernetes cluster
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone |egrep -o "[a-z]{2}\-(east|west|north|south|central)(east|west)?\-[0-9]")


  # c. Download the CoreDNS manifest from the Amazon EKS resource bucket.

  curl -o ${XDG_RUNTIME_DIR}/dns.yaml https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2019-02-11/dns.yaml

  # d. Replace the variable placeholders in the dns.yaml file with your environment variable values and apply the updated manifest to your cluster. The following command completes this in one step.

  #cat ${XDG_RUNTIME_DIR}/dns.yaml | sed -e "s/REGION/$REGION/g" -e "s/DNS_CLUSTER_IP/$DNS_CLUSTER_IP/g" | g3kubectl apply -f -
  sed -e "s/REGION/$REGION/g" -e "s/DNS_CLUSTER_IP/$DNS_CLUSTER_IP/g" ${XDG_RUNTIME_DIR}/dns.yaml | g3kubectl apply -f -

  # let's just not flood ${XDG_RUNTIME_DIR}
  rm ${XDG_RUNTIME_DIR}/dns.yaml 

  # e. Fetch the coredns pod name from your cluster.

#  COREDNS_POD=$(g3kubectl get pod -n kube-system -l eks.amazonaws.com/component=coredns -o jsonpath='{.items[0].metadata.name}')
#  COREDNS_POD=$(g3kubectl get pod -n kube-system -l eks.amazonaws.com/component=coredns -o name |cut -d/ -f2)


  # f. Query the coredns pod to ensure that it's receiving requests.

  #g3kubectl get --raw /api/v1/namespaces/kube-system/pods/${COREDNS_POD}:9153/proxy/metrics | grep 'coredns_dns_request_count_total'
#  for i in $(g3kubectl get pod -n kube-system -l eks.amazonaws.com/component=coredns -o name |awk -F/ '{print $2}')
#  do
#    echo $i
#    g3kubectl get --raw /api/v1/namespaces/kube-system/pods/${i}:9153/proxy/metrics | grep 'coredns_dns_request_count_total'
#  done
  

# Output example for the above commands.
# HELP coredns_dns_request_count_total Counter of DNS requests made per zone, protocol and family.
# TYPE coredns_dns_request_count_total counter
# coredns_dns_request_count_total{family="1",proto="udp",server="dns://:53",zone="."} 23


# 3. Scale down the kube-dns deployment to zero replicas.

  # 3.1 if we don't do this before scaling down, scaling down won't happen ever
  g3kubectl delete deployment -n kube-system kube-dns-autoscaler

  # give it a little time to delete, lucky seven
  sleep 7

  # 3.2 actual scaling down
  g3kubectl scale -n kube-system deployment/kube-dns --replicas=0



# 4. Clean up the old kube-dns resources.
COUNT=0

while [ ${COUNT} -lt 10 ];
do
  if ( ! g3kubectl get pod -n kube-system -l eks.amazonaws.com/component=kube-dns > /dev/null 2>&1 ) || [[ $(g3kubectl get deployments. -n kube-system kube-dns -o json |jq '.status.readyReplicas') -eq 0 ]];
  then
    g3kubectl delete -n kube-system deployment/kube-dns serviceaccount/kube-dns configmap/kube-dns
    break
  else
    COUNT=$(( COUNT + 1 ))
    g3kubectl get deployments. -n kube-system kube-dns 
    sleep 30
  fi
done
  

# 5. Finally, coreDNS is deployed with 2 replicas by default. It should be enough for most cases.
#    We are going to set up the autoscaler just in case

gen3 kube-setup-kube-dns-autoscaler --force
