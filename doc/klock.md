# TL;DR

Manage distributed locks

## Use

### lock
```
  gen3 klock lock lock-name owner max-age [--wait wait-time]
```
Attempts to lock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
is set to. Exits 0 if the lock is obtained and 1 if it is not obtained.

  - lock-name: string, name of lock
  - owner: string, name of owner - silently truncated to 45 characters
  - max-age: int, number of seconds for the lock to persist before expiring
  -  -w, --wait: option to make lock spin wait
  - wait-time: int, number of seconds to spin wait for

### unlock
```
  gen3 klock unlock lock-name owner
```

Attempts to unlock the lock lock-name in the namespace that KUBECTL_NAMESPACE 
is set to. Exits 0 if the lock is unlocked and 1 if it fails.  The owner is silently truncated to 45 characters.

### list
```
   gen3 klock list
```

List basic information on existing locks.