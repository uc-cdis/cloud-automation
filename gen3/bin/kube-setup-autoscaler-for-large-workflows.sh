#!/bin/bash

# Set the resources block for the deployment
kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {"limits":{"cpu":"6","memory":"30Gi"},"requests":{"cpu":"1","memory":"4Gi"}}}]'

# Add options to the command for the container
kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--scale-down-delay-after-delete=2m"}, {"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--scale-down-unneeded-time=2m"}, {"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--scan-interval=60s"}]'

# Add PriorityClass to the pod
kubectl patch deployment cluster-autoscaler -n kube-system --type=json -p='[{"op": "add", "path": "/spec/template/spec/priorityClassName", "value": "system-node-critical"}]'
