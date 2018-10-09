# TL;DR

Acquire a distributed lock of the given name for the specified duration.

## Use

```
  gen3 kube-lock lock-name owner max-age [--wait wait-time]:
    Attempts to lock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
    is set to. Exits 0 if the lock is obtained and 1 if it is not obtained.
      lock-name: string, name of lock
      owner: string, name of owner
      max-age: int, number of seconds for the lock to persist before expiring
      -w, --wait: option to make lock spin wait
        wait-time: int, number of seconds to spin wait for
```
