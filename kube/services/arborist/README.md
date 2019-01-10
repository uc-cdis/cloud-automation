# arborist
Gen3 RBAC policy engine

### current usage
Used by arranger api to retrieve authorized resources.

### Create service in new Commons
Arborist currently relies on syncing authorization from fence usersync job/cronjob. To create the service in a Commons that doesn't have arborist before, you will need to:
```
PULL LATEST CLOUD-AUTOMATION
kubectl delete secret fence-secret
gen3 kube-setup-secrets
gen3 kube-setup-networkpolicy
gen3 kube-setup-arborist
```
After arborist is up, run `g3k runjob usersync`


### Roll new version
arborist doesn't have data persistence right now, everytime arborist is rolled, you will need to run `g3k runjob usersync` again
