# TL;DR

Helpers that integrate gen3 gitops configuration with kubernetes.

## Use

### filter

Apply manifest variable substitions on the given yaml file.

`gen3 gitops filter path/to/file.yaml [optional path to manifest.json] [optional key1 value1 key2 value2 ...]

Ex:
```
gen3 gitops filter cloud-automation/kube/services/fence/fence-deploy.yaml GEN3_DEBUG_FLAG True
```


### configmaps

Update the manifest derived (`manifest-*`) configmaps.

```
gen3 gitops configmaps
```

### sync

Update the dictionary URL and image versions. The `--dryrun` flag can be used to display dictionary URL and image version check logs but do not want to roll pods.

```
gen3 gitops sync
gen3 --dryrun gitops sync
```
