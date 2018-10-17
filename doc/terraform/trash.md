# TL;DR

Move the current workspace folder to the trash.

## Use

```
  gen3 trash [--apply]:
    Move the local folder of the current workspace to the gen3 trash folder.
    This is just a local cleanup - it does not affect cloud resources or
    the configs backed up in S3.
    
    --apply must be passed - otherwise the help is given.
    dryrun with: gen3 --dryrun trash --apply
```
