# TL;DR

Deploy and manage canary services. The reverse proxy [readme](../kube/services/revproxy/README.md) has more details.

## Use

To change the branch a canary service is pointing to, just edit the `<service>-canary` in the manifest. Then `gen3 roll <service>-canary`

To change the probability that a client is directed to the canary service:
* update the service's value in the `canary` section of the manifest. Provide an integer between 0 and 100, where 0 means 0% of clients are directed to the canary, and 100 means 100% of the clients are directed to the canary service
* deploy the reverse proxy, run `gen3 kube-setup-revproxy`

To create a new canary release of a service:
* copy the deployment and service yaml files into the same directory with name `<service>-canary-<deployment/service>.yaml
* add `release: canary` and `release: production` to the files
* update the image in the deployment file: `GEN3_<SERVICE>-CANARY_IMAGE|-GEN3_<SERVICE>_IMAGE-|`