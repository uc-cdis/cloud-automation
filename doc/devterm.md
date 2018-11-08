# TL;DR

Open a terminal session on a utility pod launched onto the k8s cluster

## Example

* `gen3 devterm`
* the `devterm` command can also pass a command to the bash shell (`bash -c`) - ex:
```
gen3 devterm "nslookup fence-service"
```
