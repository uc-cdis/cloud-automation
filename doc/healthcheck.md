# TL;DR

Finds unhealthy pods and nodes

## Use
```
gen3 healthcheck [--slack] [--retry]
```
Parameters
  - --slack: if health check fails, notify slack with results
  - --retry: if health check fails, briefly wait before retrying the healthcheck
