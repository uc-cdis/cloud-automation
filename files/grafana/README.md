# Grafana Dashboards

The Grafana dashboards in `dashboards/` folder will be available in all Grafana deployments.

To add new dashboard, just put it in the folder and re-deploy Grafana.

* `data-commons-metrics.json`: buffed default Prometheus dashboard with Kubernetes metrics. Shows:
    * Cluster Health & Metrics
    * Per Pod metrics for CPU & Memory usage
    * Deployments status
    * Nodes status
    * Pods status (Running, Pending, Failed etc)
    * Containers status (Running, Waiting, Terminating etc)
    * Jobs status (Succeed, Active, Failed)
* `misc.json`: (in development) a simple dashboard to show the number of "Pending" pods.
