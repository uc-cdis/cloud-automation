# TL;DR

Release a distributed lock (goes with [kube-lock](./kube-lock.md))

# Use

```
  gen3 kube-unlock lock-name owner:
    Attempts to unlock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
    is set to. Exits 0 if the lock is unlocked and 1 if it fails.
```
