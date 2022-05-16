# TL;DR

Setup the aws-load-balancer-controller and an ALB. 

This is a replacement for the revproxy-service-elb

## Overview

The script deploys the `aws-load-balancer-controller` when run in the `default` namespace.

## Use

### deploy

Deploy the aws-load-balancer-controller from https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html.
Only works in the `default` namespace.

```
gen3 kube-setup-ingress
```

### check

Check if the metrics server has been deployed and is healthy by
polling the status of k8s API's:
```
g3kubectl get apiservices.apiregistration.k8s.io
```

ex:
```
if gen3 kube-setup-metrics check; then
    ... deploy some horizontal autoscaler ...
```
