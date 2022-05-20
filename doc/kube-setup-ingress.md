# TL;DR

Setup the aws-load-balancer-controller and an ALB. 

This is a replacement for the revproxy-service-elb

## Overview

The script deploys the `aws-load-balancer-controller` when run in the `default` namespace.

## Use

### deploy

Deploy the aws-load-balancer-controller from https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html.
Only works in the `default` namespace.

If ran from a non-default namespace it will only deploy the k8s ingress resource. 

```
gen3 kube-setup-ingress
```

### check

Check if the ingress has been deployed by running 

```
helm status aws-load-balancer-controller -n kube-system
```

Update your DNS records to the ADDRESS field from the output of 
```
kubectl get ingress revproxy-ingress
```
