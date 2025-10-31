# TL;DR

Open a terminal session on a utility pod launched onto the k8s cluster

## Use

```
gen3 devterm [--image image] [--nopull] [--labels labels] [--sa saname] [--namespace namespace] [--user username] [sh|/bin/sh] [-c|--command ...]
```

* sa overrides the default "jenkins-service" service account
* username is attached to the `gen3username` annotation that the WTS keys off of

## Example

* `gen3 devterm`
* the `devterm` command can also pass a command to the bash shell (`bash -c`) - ex:
```
gen3 devterm "dig +noall +answer fence-service"
```

* invoke `sh` instead of `bash`, and override the labels (for testing networkpolicy or whatever)
```
gen3 devterm --labels 'app=revproxy' sh
```

* run the `fence` image, but do not `pull` a fresh image if not necessary
```
gen3 devterm --image quay.io/cdis/fence:master --nopull
```

* run a devterm in the jupyter namespace as `frickjack@uchicago.edu`
```
gen3 devterm --namespace "$(gen3 jupyter j-namespace)" --env "PARENT_NAMESPACE=$(gen3 api namespace)" --user frickjack@uchicago.edu
```
