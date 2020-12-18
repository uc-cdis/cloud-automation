# TL;DR

A general utility image for running the `gen3` utilities in various contexts:

* batch jobs
* dev term
* sshd for tty remote-admin service

## Building

Build in the context of the parent `cloud-automation/` folder:

```
docker build -t awshelper:forme -f Dockerfile ../../
```
