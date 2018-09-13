# TL;DR

The autoscaler deployment talks directly to the AWS autoscaling group when the kubernetes cluster need to either scale out or in. 

By default, AWS would monitor CPU utilization on the nodes and trigger scaling rules depending on the case. However, it would not do the same for memory utilization, for that you would need to code your own module to make it work with cloudwatch alert and then scale your cluster accordingly.

Thankfully, kubernetes already thought of this and deployed something tailored to work with auscaling. More information can be found at https://github.com/kubernetes/autoscaler


## Nodedrainer

Nodrainer is also a helper to keep things smoothly within kubernetes clusters. It would help out removing pods on a node that is in a "Termination:wait" state in AWS ( it could also work for other providers ). This is very helpful when you are trying to cleat a node but don't want to mess with the kube-system deployments. 

This particular aproach/solution is not something deployed by kubernetes itself, but by the people from kube-aws. More information can be found at https://github.com/kubernetes-incubator/kube-aws

Additionally, this is not a released project, but an idea taken from this repo. So far our implementation works well with EKS.

