#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

# Set the cluster name variable
CLUSTER_NAME=`gen3 api environment`

# Cd into Cloud-automation repo and pull the latest from master
echo "Pulling the latest from Cloud-Auto"
cd /home/$CLUSTER_NAME/cloud-automation || exit
git checkout master
git pull

# Update the Karpenter Provisioner
echo "Apply new Karpenter Provisioner" 
gen3 kube-setup-karpenter deploy --force || exit 1

# Cordon all the nodes before running "gen3 roll all"
echo "Cordoning all nodes"
kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v '^fargate' | xargs -I{} kubectl cordon {}

# Run a "gen3 roll all" so all nodes use the new mounted BPF File System
echo "Cycling all the nodes by running "gen3 roll all"
gen3 roll all || exit 1

# Delete all existing network policies
echo "Deleting networkpolicies"
kubectl delete networkpolicies --all

# Delete all Calico related resources from the “kube-system” namespace
echo "Deleting all Calico related resources"
kubectl get deployments -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete deployment -n kube-system
kubectl get daemonsets -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete daemonset -n kube-system
kubectl get services -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete service -n kube-system
kubectl get replicasets -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete replicaset -n kube-system

# Backup the current VPC CNI configuration in case of rollback
echo "Backing up current VPC CNI Configuration..."
kubectl get daemonset aws-node -n kube-system -o yaml > aws-k8s-cni-old.yaml || exit 1

# Check to ensure we are not using an AWS plugin to manage the VPC CNI Plugin
if aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name vpc-cni --query addon.addonVersion --output text 2>/dev/null; then
    echo "Error: VPC CNI Plugin is managed by AWS. Please log into the AWS UI and delete the VPC CNI Plugin in Amazon EKS, then re-run this script."
    exit 1
else
    echo "No managed VPC CNI Plugin found, proceeding with the script."
fi

# Apply the new VPC CNI Version
echo "Applying new version of VPC CNI"
g3kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.14.1/config/master/aws-k8s-cni.yaml || exit 1

# Check the version to make sure it updated
NEW_VERSION=$(kubectl describe daemonset aws-node --namespace kube-system | grep amazon-k8s-cni: | cut -d : -f 3)
echo "Current version of aws-k8s-cni is: $NEW_VERSION"
if [ "$NEW_VERSION" != "v1.14.1" ]; then
    echo "The version of aws-k8s-cni has not been updated correctly."
    exit 1
fi

# Edit the amazon-vpc-cni configmap manually to enable network policy controller
echo "Enabling NetworkPolicies in VPC CNI Configmap"
kubectl patch configmap -n kube-system amazon-vpc-cni --type merge -p '{"data":{"enable-network-policy-controller":"true"}}' || exit 1


# Edit the aws-node daemonset manually
echo "Enabling NetworkPolicies in aws-node Daemonset"
kubectl patch daemonset aws-node -n kube-system --type json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["--enable-network-policy=true"]}]' || exit 1

# Ensure all the aws-nodes are running
echo "Manually check that all aws-node pods have '2/2' containers running... If so, please run 'kube-setup-networkpolicy'"
kubectl get pods -n kube-system | grep aws