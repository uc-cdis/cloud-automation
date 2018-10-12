# TL;DR

Update the specified gen3 k8s deployment using the manifest filter.
The `gen3 roll` command does not update configuration when applied to a single service,
but `gen3 roll all` will check for missing configuration, and run `kube-setup-*` scripts.

## Example

* `gen3 roll sheepdog`
* `gen3 roll all`
