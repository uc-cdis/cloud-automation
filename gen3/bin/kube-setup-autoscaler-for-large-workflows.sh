#!/bin/bash

# Set the resources block for the deployment
kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {"limits":{"cpu":"6","memory":"30Gi"},"requests":{"cpu":"1","memory":"4Gi"}}}]'

# Add options to the command for the container, if they are not already present
if ! kubectl get deployment cluster-autoscaler -n kube-system -o jsonpath='{.spec.template.spec.containers[0].command}' | yq eval '.[]' | grep -q -- '--scale-down-delay-after-delete=2m'; then
  kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--scale-down-delay-after-delete=2m"}]'
else
  echo "Flag --scale-down-delay-after-delete=2m already present"
fi

if ! kubectl get deployment cluster-autoscaler -n kube-system -o jsonpath='{.spec.template.spec.containers[0].command}' | yq eval '.[]' | grep -q -- '--scale-down-unneeded-time=2m'; then
  kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--scale-down-unneeded-time=2m"}]'
else
  echo "Flag --scale-down-unneeded-time=2m already present"
fi

if ! kubectl get deployment cluster-autoscaler -n kube-system -o jsonpath='{.spec.template.spec.containers[0].command}' | yq eval '.[]' | grep -q -- '--scan-interval=60s'; then
  kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--scan-interval=60s"}]'
else
  echo "Flag --scan-interval=60s already present"
fi

# Add PriorityClass to the pod
kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/priorityClassName", "value": "system-node-critical"}]'
