# TL;DR

Update the specified gen3 k8s deployment using the manifest filter.
The `gen3 roll` command does not update configuration when applied to a single service,
but `gen3 roll all` will check for missing configuration, and run `kube-setup-*` scripts.
`gen3 roll $APP_NAME -w` will update the pod and wait until it is ready.

## Example

* `gen3 roll sheepdog`
* `gen3 roll all`
* Note that gen3 template `key` `value` pairs may also be passed on the command line - ex:
```
gen3 roll fence GEN3_DEBUG_FLAG True
```
