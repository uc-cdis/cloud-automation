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

Update the `manifest.json` derived (`manifest-*`) configmaps.

```
gen3 gitops configmaps
```

The configmaps command also harvests configmaps from the `manifests/` subdirectory.
For example:
```
cd $(dirname $(g3k_manifest_path))
mkdir -p manifests/hatchery
jq -r .hatchery < manifest.json | tee manifests/hatchery/hatchery.json
```

Given a folder `manifests/key/` with files `a.json` and `b.json` and `key.json` - gitops manifests will create a configmap `manifest-key` with keys `a.json`, `b.json` and `key.json`; and it will also create a key `json` with the same content as `key.json` (to make it easy to pull values out of the root `manifest.json`).

Finally - the harvest also loads configuration from `${GEN3_HOME}/gen3/lib/manifestDefaults/` if that folder contains a key that does not already exist in `manifest.json` or the `manfiests/` folder.

Note: if a key exists both under the `manifests/` folder and in `manifest.json`, then only the data under `manifests/` persists in the configmap

### enforce

Force the local `cdis-manifest/` and `cloud-automation/` folders to sync with github.

```
gen3 gitops enforce
```

### folder

Get the active manifest folder path.

```
folder="$(gen3 gitops folder)"
```

### history

Show the git history of changes to the manifest folder

```
gen3 gitops history
```

### manifest

Get the path to the active manifest

```
path="$(gen3 gitops manifest)"
```

### rsync

Run `gen3 gitops sync` on the given `ssh` target.
See `gen3 gitops sshlist` and `gen3 gitops sync` below.


```
gen3 gitops rsync reuben@cdistest.csoc
```

### sshlist

List the cdis gen3 admin machines.

```
gen3 gitops sshlist
```

### sync

Update the dictionary URL and image versions. The `--dryrun` flag can be used to display dictionary URL and image version check logs but do not want to roll pods.
The optional `--slack` flag sends an update to the commons' slack channel (if any). 

```
gen3 gitops sync --slack
gen3 --dryrun gitops sync
```

### repolist

List the Gen3 source code repos.

```
gen3 gitops repolist
```

### rollpath

Derive the path to the `-deploy.yaml` for a service name
(or service-canary), and an optional deployment version -
pulled from the manifest if not given as an argument

```
gen3 gitops rollpath fence
gen3 gitops rollpath arborist 2
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

### tfplan

Runs terraform to check on an environment. It'll just get the plan, it won't apply it.
It must be ran as the user that manages the commons.
It takes a module as argument, like: vpc, eks.

```
gen3 gitops tfplan vpc
```

### tfapply
Runs a terraform plan on an environment. It must be ran as the user that manages the commons.
Execute this with extream precaution, it won't prompt for confirmation, will just apply.
It takes a module as argument, like: vpc, eks.

```
gen3 gitops tfapply eks
```
