# TL;DR

Devops only - deploy the cluster autoscaler

## Overview

Deploy cluster autoscaler in a kubernetes cluster. At the moment it works only for AWS EKS clusters.

https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler

This is automatically installed when gen3 is deployed, and it is part of `gen3 roll all`

## Deploy

Ex:

`gen3 kube-setup-autoscaler [-v <version>] [-f] `

The version to install is predefined in the script, but you can set your own by passing the -v|--version argument


```
gen3 kube-setup-autoscaler -h
  Usage: kube-setup-autoscaler [-v] <version> [-f]
  Options:
  No option is mandatory, however you can provide the following:
          -v num       --version num       --create=num        Cluster autoscaler version number
          -f           --force                                 Force and update if it is already installed
```

