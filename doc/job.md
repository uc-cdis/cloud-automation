# TL;DR

Kubernetes batch job helper

## Use

```
gen3 job sub-command
```
where sub-command is one of:
* run [jobname or path]
  - if given a jobname, then looks for `${jobname}-job.yaml` in [cloud-automation/kube/services/jobs](https://github.com/uc-cdis/cloud-automation/tree/master/kube/services/jobs) after:

  - if given a path, then assumes a path ending in `-cronjob.yaml` is a cron job
  - executes the `${jobname}-job.sh` script if present
  - filters the `yaml` file as a manifest template via [gen3 gitops filter](./filter.md)

* logs name

Cat the logs for the most recently launched `gen3 job`.
Note that when `gen3 job logs jobname` runs immediately after a `gen3 job run jobname` command
may output messages something like `error pod not running` until the
job's pods launch.


* pods name


## Example

* `gen3 job run usersync`
* `gen3 job logs usersync`
* in a loop:
```
while true; do gen3 job logs usersync; sleep 3; done
```
