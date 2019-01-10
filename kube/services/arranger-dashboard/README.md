# TL;DR

Arranger dashboard deployment - access via port-forwarding through the CSOC admin VM.

## Port forwarding

* First pick an OFFSET in the range 0-1000 unique to yourself, so multiple people can port forward on the same admin vm (ex - cdistest.csoc):
```
OFFSET=100 # something unique
```

* Login to the admin vm, then:
    - launch the arranger-dashboard if it's not already running: 
       `gen3 roll arranger-dashboard`
    - forward the dashboard ports to the admin vm
```
OFFSET=...  # same as above
g3kubectl port-forward deployment/arranger-dashboard-deployment $((OFFSET + 6060)):6060 $((OFFSET+5050)):5050 &
g3kubectl port-forward deployment/aws-es-proxy-deployment $((OFFSET+9200)):9200 &

```

[port-forward details](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

* then forward the ports on the admin-vm to your local machine with ssh

```
OFFSET=...  # same as above
LOGINNAME=yourLogin
ssh -L 127.0.0.1:6060:localhost:$((OFFSET + 6060)) -L 127.0.0.1:5050:localhost:$((OFFSET + 5050)) -L 127.0.0.1:9200:localhost:$((OFFSET + 9200)) ${LOGINNAME}@cdistest.csoc
```

* finally - connect to the dashboard: http://localhost:6060
* can also interact with the ES cluster via http://localhost:9200 
```
source gen3-arranger/Docker/Stacks/esearch/indexSetup.sh
es_indices
```
