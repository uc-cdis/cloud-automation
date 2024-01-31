#!/bin/bash

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

#Get the K8s NS
ctx="$(g3kubectl config current-context)"
ctxNamespace="$(g3kubectl config view -ojson | jq -r ".contexts | map(select(.name==\"$ctx\")) | .[0] | .context.namespace")"

# Set the cluster name variable
CLUSTER_NAME=`gen3 api environment`

# Check if in default ns
if [[ ("$ctxNamespace" != "default" && "$ctxNamespace" != "null") ]]; then
    gen3_log_err "Namespace must be default"
    exit 1
fi

# Cd into Cloud-automation repo and pull the latest from master
gen3_log_info "Pulling the latest from Cloud-Auto"
cd /home/$CLUSTER_NAME/cloud-automation || { gen3_log_err "Cloud-automation repo not found"; exit 1; }
#### Change to master
git checkout master || { gen3_log_err "Failed to checkout master branch"; exit 1; }
git pull || { gen3_log_err "Failed to pull from the repository"; exit 1; }

# Update the Karpenter Node Template
gen3_log_info "Apply new Karpenter Node Template"
if [[ -d $(g3k_manifest_init)/$(g3k_hostname)/manifests/karpenter ]]; then
    gen3_log_info "Karpenter setup in manifest. Open a cdismanifest PR and add this line to aws node templates: https://github.com/uc-cdis/cloud-automation/blob/master/kube/services/karpenter/nodeTemplateDefault.yaml#L40"
    while true; do
        read -p "Have you updated your manifest? (yes/no): " yn
        case $yn in
            [Yy]* ) 
                gen3_log_info "Proceeding with Karpenter deployment..."
                gen3 kube-setup-karpenter deploy --force || { gen3_log_err "kube-setup-karpenter failed"; exit 1; }
                break
                ;;
            [Nn]* ) 
                gen3_log_info "Please update the cdismanifest before proceeding."
                exit 1
                ;;
            * ) 
                gen3_log_info "Please answer yes or no."
                ;;
        esac
    done
else
    gen3 kube-setup-karpenter deploy --force || { gen3_log_err "kube-setup-karpenter failed"; exit 1; }
fi

# Cordon all the nodes before running gen3 roll all"
gen3_log_info "Cordoning all nodes"
kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v '^fargate' | xargs -I{} kubectl cordon {}

# Run a "gen3 roll all" so all nodes use the new mounted BPF File System
gen3_log_info "Cycling all the nodes by running gen3 roll all"
gen3 roll all --fast || exit 1

# Confirm that all nodes have been rotated
while true; do
    read -p "Roll all complete. Have all cordoned nodes been rotated? (yes/no): " yn
    case $yn in
        [Yy]* ) 
            gen3_log_info "Continuing with script..."
            break
            ;;
        [Nn]* ) 
            gen3_log_info "Please drain any remaining nodes with 'kubectl drain <node_name> --ignore-daemonsets --delete-emptydir-data'"
            ;;
        * ) 
            gen3_log_info "Please answer yes or no."
            ;;
    esac
done


# Delete all existing network policies
gen3_log_info "Deleting networkpolicies"
kubectl delete networkpolicies --all

# Delete all Calico related resources from the “kube-system” namespace
gen3_log_info "Deleting all Calico related resources"
kubectl get deployments -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete deployment -n kube-system
kubectl get daemonsets -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete daemonset -n kube-system
kubectl get services -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete service -n kube-system
kubectl get replicasets -n kube-system | grep calico | awk '{print $1}' | xargs kubectl delete replicaset -n kube-system

# Backup the current VPC CNI configuration in case of rollback
gen3_log_info "Backing up current VPC CNI Configuration..."
kubectl get daemonset aws-node -n kube-system -o yaml > aws-k8s-cni-old.yaml || { gen3_log_err "Error backig up VPC CNI configuration"; exit 1; }

# Check to ensure we are not using an AWS plugin to manage the VPC CNI Plugin
if aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name vpc-cni --query addon.addonVersion --output text 2>/dev/null; then
    gen3_log_err "Error: VPC CNI Plugin is managed by AWS. Please log into the AWS UI and delete the VPC CNI Plugin in Amazon EKS, then re-run this script."
    exit 1
else
    gen3_log_info "No managed VPC CNI Plugin found, proceeding with the script."
fi

# Apply the new VPC CNI Version
gen3_log_info "Applying new version of VPC CNI"
g3kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.14.1/config/master/aws-k8s-cni.yaml || { gen3_log_err "Failed to apply new VPC CNI version"; exit 1; }

# Check the version to make sure it updated
NEW_VERSION=$(kubectl describe daemonset aws-node --namespace kube-system | grep amazon-k8s-cni: | cut -d : -f 3)
gen3_log_info "Current version of aws-k8s-cni is: $NEW_VERSION"
if [ "$NEW_VERSION" != "v1.14.1" ]; then
    gen3_log_info "The version of aws-k8s-cni has not been updated correctly."
    exit 1
fi

# Edit the amazon-vpc-cni configmap to enable network policy controller
gen3_log_info "Enabling NetworkPolicies in VPC CNI Configmap"
kubectl patch configmap -n kube-system amazon-vpc-cni --type merge -p '{"data":{"enable-network-policy-controller":"true"}}' || { gen3_log_err "Configmap patch failed"; exit 1; }

# Edit the aws-node daemonset
gen3_log_info "Enabling NetworkPolicies in aws-node Daemonset"
kubectl patch daemonset aws-node -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/1/args", "value": ["--enable-network-policy=true", "--enable-ipv6=false", "--enable-cloudwatch-logs=false", "--metrics-bind-addr=:8162", "--health-probe-bind-addr=:8163"]}]' || { gen3_log_err "Daemonset edit failed"; exit 1; }

# Ensure all the aws-nodes are running
kubectl get pods -n kube-system | grep aws
while true; do
    read -p "Do all the aws-node pods in the kube-system ns have 2/2 containers running? (yes/no): " yn
    case $yn in
        [Yy]* ) 
            gen3_log_info "Running kube-setup-networkpolicy..."
            gen3 kube-setup-networkpolicy || exit 1
            break
            ;;
        [Nn]* ) 
            gen3_log_err "Look at aws-node logs to figure out what went wrong. View this document for more details: https://docs.google.com/document/d/1fcBTciQSSwjvHktEnO_7EObY-xR_EvJ2NtgUa70wvL8"
            gen3_log_info "Rollback instructions are also available in the above document"
            ;;
        * ) 
            gen3_log_info "Please answer yes or no."
            ;;
    esac
done