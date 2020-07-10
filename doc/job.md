# TL;DR

Kubernetes batch job helper

## Use

### gen3 job run $jobnameOrPath [-w] [kv arguments]

- if given a jobname, then looks for `${jobname}-job.yaml` in [cloud-automation/kube/services/jobs](https://github.com/uc-cdis/cloud-automation/tree/master/kube/services/jobs) after:

- if given a path, then assumes a path ending in `-cronjob.yaml` is a cron job
- filters the `yaml` file as a manifest template via [gen3 gitops filter](./filter.md)
- passing `-w` right after the `jobname` (before its arguments) if wait for job finish

```
gen3 job run usersync
```

### gen3 job json $jobnameOrPath [kv arguments]

Generate the json that `gen3 job run` forwards to kubernetes to create the job.

```
gen3 job json usersync
```

### gen3 job cron $jobnameOrPath $cronSchedule [kv arguments]

Launch the given job as a kubernetes cron job that runs on the given 
[cron schedule](https://en.wikipedia.org/wiki/Cron).

```
gen3 job cron es-garbage @daily
```

### gen3 job cron-json $jobnameOrPath $cronSchedule [kv arguments]

Generate the json that `gen3 job cron` forwards to kubernetes to create the cron job.

```
gen3 job cron-json es-garbage @daily
```

### gen3 job logs jobname [-f]

Cat the logs for the most recently launched `gen3 job`.
Note that when `gen3 job logs jobname` runs immediately after a `gen3 job run jobname` command
may output messages something like `error pod not running` until the
job's pods launch.

```
gen3 job logs usersync
```

### gen3 job pods jobname

Get the pods associated with the given jobname - just does a prefix match

```
gen3 job pods usersync
```

## Example

* `gen3 job run usersync`
* `gen3 job logs usersync`
* tail the logs: `gen3 job logs usersync -f`
