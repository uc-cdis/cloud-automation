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

### repolist

List the Gen3 source code repos.

```
gen3 gitops repolist
```

### taglist

List the 5 largest semver tags associated with each Gen3 code repository.

```
gen3 gitops taglist
```

### dotag

Generate the next `patch` release tag for the specified repository, and push to github
using the caller's ssh key for authentication.
We expect a user will usually run this command from his personal laptop which hosts her git authentication keys.

```
gen3 gitops dotag fence
```
