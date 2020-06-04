# TL;DR

We deploy [prometheus](https://prometheus.io) onto a kubernetes cluster with `kube-setup-prometheus`.

## Overview

Add an annotation to a pod for prometheus to discover and harvest the metrics published by the pod:
https://github.com/helm/charts/tree/master/stable/prometheus#scraping-pod-metrics-via-annotations

For example, this is the ambassador metrics endpoint: 


Query prometheus from a devterm with stuff like this:
```
ttl=12h
promQuery="sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{kubernetes_namespace=\"$(gen3 db namespace)\"}[${ttl}]))"
urlPath="prometheus/api/v1/query?query=$(gen3_encode_uri_component "$promQuery")"

curl -s -H 'Accept: application/json' "http://prometheus-server.prometheus.svc.cluster.local/$urlPath" | jq -r .
```

Query from a client with an API key like this 
```
curl -s -H 'Accept: application/json' -H "Authorization: bearer $accessToken" https://dev.planx-pla.net/prometheus/api/v1/query?query=envoy_cluster_upstream_rq_total%7Benvoy_cluster_name%3D%22cluster_h_reubenonrye_40uchicago_2eedu_s-0%22%7D&time=1588861793.032&_=1588861702639
```
, or use the `gen3 api curl` helper:
```
gen3 api curl 'prometheus/api/v1/query?query=envoy_cluster_upstream_rq_total%7Benvoy_cluster_name%3D%22cluster_h_reubenonrye_40uchicago_2eedu_s-0%22%7D&time=1588861793.032&_=1588861702639' ~/.gen3/devplanetv1.json
```

The `gen3 prometheus query` helper (see below) simplifies query construction.

We only deploy prometheus to the `default` namespace.


The prometheus site has more [query documentation](https://prometheus.io/docs/prometheus/latest/querying/functions/).

The [jupyter idle](./jupyter.md#idle) job queries prometheus to identify applications that have not been accessed by ambassador.

## Hepers

### gen3 prometheus query $query $apiToken

Query prometheus directly (in a `devterm` or k8s job) or through the prometheus endpoint accessible in the `default` namespace of a commons.

Ex:
* query from a devterm
```
promQuery="sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{kubernetes_namespace=\"default\"}[12h]))"
gen3 prometheus query "$promQuery"
```

* query from an admin vm

Note - this only works in the `default` namespace.
```
promQuery="sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{kubernetes_namespace=\"default\"}[12h]))"
gen3 prometheus query "$promQuery" reubenonrye@uchicago.edu
```

* query with an api key
```
promQuery="sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{kubernetes_namespace=\"default\"}[12h]))"
gen3 prometheus query "$promQuery" ~/.gen3/devplanetv1.json
```

### gen3 prometheus list $apiKey

List the available prometheus metrics.  Assumes its running
on the cluster if `$apiKey` is not provided.
Ex:

```
gen3 prometheus list ~/.gen3/devplanetv1.json
```

### gen3 prometheus curl $urlBase $apiKey

Issue a `GET` request to the prometheus endpoint.  Assumes its running
on the cluster if `$apiKey` is not provided.

Ex:
```
gen3 prometheus curl label/__name__/values
```
