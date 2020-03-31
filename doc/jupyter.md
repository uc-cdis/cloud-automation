# TL;DR

Helpers for operating jupyterhub.

## Use

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
