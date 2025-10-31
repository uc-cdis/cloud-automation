# TL;DR

Use: `gen3 kube-wait4-pods ${NumRetries:-90}`

Wait for pending pods to enter a healthy `Running` state.
The script polls the running pods every 10 seconds up to 90 
times (configurable on the command line) before giving up.

Ex:
```
if gen3 kube-wait4-pods 10; then
  gen3_log_info "all deployed pods are running!"
fi
```