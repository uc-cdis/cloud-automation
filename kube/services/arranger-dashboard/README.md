# TL;DR

Arranger dashboard deployment - access via port-forwarding through the CSOC admin VM.

## Port forwarding

* Login to the admin vm, then:
    - launch the arranger-dashboard if it's not already running: 
       `gen3 roll arranger-dashboard`
    - forward the dashboard ports to the admin vm
```
g3kubectl port-forward deployment/arranger-dashboard-deployment 6060 5050 &
g3kubectl port-forward deployment/aws-es-proxy-deployment 9200 &

```

[port-forward details](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

* then forward the ports on the admin-vm to your local machine with ssh

```
ssh -L 6060:localhost:6060 -L 5050:localhost:5050 -L 9200:localhost:9200 cdistest.csoc
```

* finally - connect to the dashboard: http://localhost:6060
* can also interact with the ES cluster via http://localhost:9200 
```
source gen3-arranger/Docker/Stacks/esearch/indexSetup.sh
es_indices
```
