# TL;DR

Helpers for operating jupyterhub.

## Use

### gen3 jupyter idle [apiKey] [list|kill]

List the idle hatchery services (according to prometheus)
for the current namespace.  

Accepts an optional `gen3 api curl` api
key - otherwise assumes the call is running on cluster with
a direct route to prometheus.  Note that only the `default`
namespace exposes a public (guarded by `arborist` policy) `/prometheus/` route.

Also accepts an optional command (defaults to `list`).  When given the `kill` command the tool attempts to kill the idle hatchery app pods it discovers.

Ex:
```
admin-vm $ gen3 devterm --sa hatchery-service-account
on-cluster $ gen3 jupyter idle
```

Ex:
```
off-cluster $ KUBECTL_NAMESPACE=my-namespace gen3 jupyter idle defaultNamespaceKey.json
```



### gen3 jupyter j-namespace

Echo the name of the jupyter namespace (derived from the current namespace).
The `default` commons namespace is associated with the `jupyter-pods` namespace,
and a namespace `X` is associated with `jupyter-pods-X`.

```
gen3 jupyter j-namespace
```

### gen3 jupyter j-namespace setup

Create and label the jupyter namespace, also label the gen3 workspace.

```
gen3 jupyter j-namespace setup
```

### gen3 jupyter prepuller [image1 image2 image3 ...]

Output yaml for the prepuller extended with images from the `manifest-jupyter`
configmap plus images optionally specified on the command line.

```
gen3 jupyter prepuller
```

### gen3 jupyter upgrade

Sync the jupyter configmaps, and reset the jupyter prepuller and hub.

### gen3 jupyter pvclear $grepFor

list persistent volumes and persistent volume claims to clear
