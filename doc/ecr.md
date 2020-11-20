# TL;DR

Helpers for interacting with [ECR](https://aws.amazon.com/ecr/).
Only works on the `cdistest` admin VM - which has the necessary AWS 
permissions for interacting with the cdistest docker registry.

## Common Tasks

### Give a new account access to the repos

* merge a PR to update the [account list](https://github.com/uc-cdis/cloud-automation/blob/master/gen3/bin/ec2.sh)
* update the policy on eachrepo
```
for name in $(gen3 ecr list); do
  echo "updating $name"
  gen3 ecr update-policy $name
done
```

### Create a new repository

```
aws ecr create-repository --repository-name "gen3/$name" --image-scanning-configuration scanOnPush=true
```

### Sync a tagged image from quay

```
tag="2020.06"
for name in $(gen3 ecr list); do
  echo "syncing $name:$tag"
  gen3 ecr quay-sync $name $tag
done
```

## Command Reference

### registry

Get the base path of the registry.
Ex:
```
reg="$(gen3 ecr registry)"
```

### login

Authenticate docker with the ECR registry if necessary.
Ex:
```
gen3 ecr login
```

### login to quay

Authenticate docker with the quay.io if necessary.
Ex:
```
gen3 ecr quaylogin
```

This requires that the password for the cdis+gen3 robot account is present in `~/Gen3Secrets/quay/login`

### copy

Copy an image from a source tag to a destination tag (pull, tag, push).
Ex:
```
gen3 ecr copy quay.io/cdis/fence:2020.05 "$(gen3 ecr registry)/gen3/fence:2020.05"
gen3 ecr copy "$(gen3 ecr registry)/gen3/fence:2020.05" "$(gen3 ecr registry)/gen3/fence:master"
```

### copy from dockerhub to quay 
Copy an image from a source tag in dockerhub to a destination tag in quay.io (pull, tag, push).
```
gen3 ecr dh-quay ubuntu:18.04 quay.io/cdis/ubuntu:18.04
```

### quay-sync

Copy an image from the given repo with the given tag to its corresponding ecr repo.

```
gen3 ecr quay-sync fence 2020.05
```

### update-policy

Update the access policy on an ECR repo

Ex:
```
gen3 ecr update-policy gen3/fence
```
