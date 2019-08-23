#!/bin/bash
#
# This script is to show basic description of a cluster running on a commons
#


# Import some basics 

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/lib/kube-setup-init"



# list the instances images for a single cluster based on the vpc_name
echo "AMI ID of the workers"
aws ec2 describe-instances --query 'Reservations[].Instances[].ImageId' --filter "Name=tag:Name,Values=eks-${vpc_name}*" --output table
echo

# Get EKS version
echo "EKS version"
aws eks describe-cluster --name ${vpc_name} --query 'cluster.version'
echo

# Get Kubernetes version from kubectl just in case 
echo "kubectl server version"
g3kubectl version -o json |jq '.serverVersion.major + " " + .serverVersion.minor'
echo

# Get CNI version 
echo "CNI version installed"
g3kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2
echo

# g3kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/v1.4/aws-k8s-cni.yaml

# Get what kind of kube-dns is using 

echo "DNS service type"
g3kubectl get deployments --all-namespaces -l k8s-app=kube-dns
echo


# There should be an easy way to get the calico version running on your cluster, but there is not.
# You may need to install calicoctl for that, but it'll still require some configurations.
# Unfortunatelly, EKS won't let you talk to ETCD just like that, or we just haven't found a way to 
# safely do so as of yet.


# As of 2019-05-17 thi is the latest version, applying the yaml should not disrupt anything but don't want 
# to automate yet
# kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/v1.4/calico.yaml


# At least we can look at what is running
echo "Calicos running"
g3kubectl get daemonset calico-node --namespace kube-system
