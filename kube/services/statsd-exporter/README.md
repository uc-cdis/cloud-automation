# TL;DR

statsd_exporter bridges metrics from ambassador to prometheus - see https://github.com/prometheus/statsd_exporter


## Debugging

```
gen3 devterm
curl http://statsd-exporter:9102/metrics
```

## Details

Prometheus operator configuration:

```
---
apiVersion: v1
kind: Service
metadata:
  name: ambassador-monitor
  labels:
    service: ambassador-monitor
spec:
  selector:
    service: statsd-sink
  type: ClusterIP
  clusterIP: None
  ports:
  - name: prometheus-metrics
    port: 9102
    targetPort: 9102
    protocol: TCP
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ambassador-monitor
  labels:
    ambassador: monitoring
spec:
  selector:
    matchLabels:
      service: ambassador-monitor
  endpoints:
  - port: prometheus-metrics
```

## References

https://www.getambassador.io/reference/statistics/
