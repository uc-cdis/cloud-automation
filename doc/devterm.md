# TL;DR

Open a terminal session on a utility pod launched onto the k8s cluster

## Use

```
gen3 devterm [--image image] [--pull] [--labels labels] [sh|/bin/sh] [-c|--command ...]
```

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

* run the `fence` image, and be sure to `pull` a fresh image
```
gen3 devterm --image quay.io/cdis/fence:master --pull
```
