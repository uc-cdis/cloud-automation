# TL;DR

Helpers for interacting with the gen3 dashboard backend.

## Overview

We make documents stored in a dashboard S3 bucket
available to clients via the dashboard API:
```
curl https://commons/dashboard/Public/...
curl https://commons/dashboard/Secure/...
```

The `dashboard` service published `public` files for general access, and `secure` files that require a user to authenticate and have the `dashboard` perission in an attached arborist policy.


## Use

### gen3 dashboard prefix

Get the S3 base path for dashboard data objects.
```
ex:
gen3 dashboard prefix
```

### gen3 dashboard publish [public|secure] local-file dest-path

Publish the local file or folder to the dashboard - either public or secure.

```
ex: 
gen3 dashboard public file.txt files/file.txt
```

### gen3 dashboard gitops-sync

Sync the gitops `dashboard/` folder - similar to:
```
gen3 dashboard publish public "$(gen3 gitops folder)/dashboard/Public/fu" "fu"
gen3 dashboard publish secure "$(gen3 gitops folder)/dashboard/Secure/bar" "bar"
```

```
ex:
gen3 dashboard gitops-sync
```
