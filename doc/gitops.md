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

### enforce

Force the local `cdis-manifest/` and `cloud-automation/` folders to sync with github.

```
gen3 gitops enforce
```

### history

Show the git history of changes to the manifest folder

```
gen3 gitops history
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
