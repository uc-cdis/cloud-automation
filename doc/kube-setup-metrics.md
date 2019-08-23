# TL;DR

Setup the k8s metrics api

## Overview

The script deploys the `metrics-server` when run in the `default` namespace.

## Use

### deploy

Deploy the metrics server from https://github.com/kubernetes-incubator/metrics-server.
Only works in the `default` namespace.

```
gen3 kube-setup-metrics deploy
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
