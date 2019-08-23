# TL;DR

Apply the gen3 network policy rules.
The policies are overlapping, so a particular pod
accumulates the union of all the rights from policies that apply to it.

## Use

### gen3 kube-setup-networkpolicy

Deploys the entire suite of network policies

### gen3 kube-setup-networkpolicy disable

Deploy an "allow everything" network policy.
May want to do this during `roll all` when 
policy roles are changing from an old set to a new set

### gen3 kube-setup-networkpolicy enable

Remove the "allow everything" policy deployed by `kube-setup-networkpolicy disable`

### gen3 kube-setup-networkpolicy jupyter

Deploys the relevent policies to the jupyter namespace.

### gen3 kube-setup-networkpolicy service $serviceName

Deploys policies that allow ingress and egress to the
specified service based on the `gen3.io/network/ingress` 
annotation in the service deployment.

## Policy Design

Our network policies attempt to restrict which pods may access which internal services
and the external internet.  We manage 2 workload classes on our kubernetes cluster:
* `gen3` workloads are services and jobs developed and maintained by gen3's development team
* `user` worloads are notebooks and workflows that we allow a commons' user to run on our cluster to simplify access to data hosted by the commons

The core `gen3` workloads run in a parent namespace
(`default` in production, but multiple `gen3` deployments share the same kubernetes cluster in `dev` and `qa`).
Most of our network policies setup rules that restrict inter-service communication
in the `gen3` namespace.  We also allow pods labeled with `internet=yes` to access the external internet.

The `user` workloads run in other namespaces labeled with `role=usercode`.
We currently allow all the pods in `usercode` namespaces to access the external internet.


### Base policies

Base policies apply to both `gen3` and `usercode` namespaces.

* [networkpolicy-allow-nothing](../kube/services/netpolicy/base/allow_nothing_netpolicy.yaml) - grants no rules for ingress or egress - so no communication by default
* [networkpolicy-external-egress](./netpolicy.md) - a procedurally generated policy - allows all pods in a `usercode` namespace to communicate with the external internet, and allows `gen3` pods labeled with `internet=yes` to communicate with the external internet.  This policy whitelists the entire IP4 address space except for the `172.16.0.0/12` and `10.0.0.0/8` CIDRs used internally.


### Gen3 policies

Most of these policies enforce constraints on interservice communication for specific internal gen3 applications, but there are also a handful of generic policies described below.

* [networkpolicy-linklocal](../kube/services/netpolicy/gen3/linklocal_netpolicy.yaml) grants egress to the `169.254.0.0/16` CIDR - which includes the AWS metadata service http://169.254.169.254/ - for pods labeled with `linklocal=yes`
* [networkpolicy-public](../kube/services/netpolicy/gen3/public_netpolicy.yaml) grants ingress from the `revproxy` service (our gateway for public API's) for pods labeled with `public=yes`
* [networkpolicy-s3](./netpolicy.md) grants egress to AWS S3 addresses for pods labeled with `s3=yes` - note that the `networkpolicy-s3` grants permissions to a superset of ip addresses that includes S3
* [networkpolicy-userhelper](../kube/services/netpolicy/auth/userhelp_netpolicy.yaml) - grants ingress from pods in `usercode` namespaces for `gen3` pods labeled with `userhelper=yes`
* [networkpolicy-auth](../kube/services/netpolicy/gen3/auth_netpolicy.yaml) - grants egress from all pods to pods labeled with `authrpovider=yes`
* [networkpolicy-vpc](../kube/services/netpolicy/gen3/vpc_netpolicy.yaml) - grants egress from all pods to any address in the vpc
* [networkpolicy-nolimit](../kube/services/netpolicy/gen3/nolimit_netpolicy.yaml) - grants egress from pods labeled with `netnolimit=yes` to any IP address

### Deployment annotations

A `service-deploy.yaml` may specify the services (identified via an `app:name` label) that may communicate with it by including a `gen3.io/network/ingress` annotation.

Ex:
```
metadata:
  name: indexd-deployment
  annotations:
    gen3.io/network/ingress: "fence,fenceshib,peregrine,sheepdog"  
```

## Resources

* AWS address ranges: https://docs.aws.amazon.com/general/latest/gr/aws-ip-ranges.html
* IP4 special use address ranges: https://en.wikipedia.org/wiki/IPv4
* Example policies: https://github.com/ahmetb/kubernetes-network-policy-recipes
