# TL;DR

We deploy [prometheus](https://prometheus.io) onto a kubernetes cluster with `kube-setup-prometheus`.

### Overview

Add an annotation to a pod for prometheus to discover and harvest the metrics:
https://github.com/helm/charts/tree/master/stable/prometheus#scraping-pod-metrics-via-annotations

For example, this is the ambassador metrics endpoint: 
```
curl -s -H 'Accept: application/json' https://dev.planx-pla.net/prometheus/api/v1/query?query=envoy_cluster_upstream_rq_total%7Benvoy_cluster_name%3D%22cluster_h_reubenonrye_40uchicago_2eedu_s-0%22%7D&time=1588861793.032&_=1588861702639
```

Query prometheus with stuff like this:
```
ttl=12h
promQuery="sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total{kubernetes_namespace=\"$(gen3 db namespace)\"}[${ttl}]))"
urlPath="prometheus/api/v1/query?query=$(gen3_encode_uri_component "$promQuery")"

curl -s -H 'Accept: application/json' "http://prometheus-server.prometheus.svc.cluster.local/$urlPath" | jq -r .
```


The prometheus site has more [query documentation](https://prometheus.io/docs/prometheus/latest/querying/functions/).

