# TL;DR

Helpers for interacting with the gen3 secrets in kubernetes 
or the admin vm secrets folder.

## Overview

We store the master copy of most of our secrets in a folder
on the home directory of a commons' admin machine.
These helpers automate the transfer of a subset of these
secrets from the secrets folder to kubernetes (`creds.json` 
and `g3auto/` secrets), and also automates maintenance 
of the local `git` repo that tracks changes 
to the secrets folder.

## Use

### gen3 secrets commit [message]

Commit any local changes in the secrets folder to git.

```
ex:
gen3 secrets commit "change fence-config - Reuben"
```

### gen3 secrets sync [message]

Runs `gen3 secrets commit $message`, then re-creates
the kubernetes `-creds` secrets (from `creds.json`), and
`-g3auto` secrets (from `g3auto/`).

```
ex:
gen3 secrets sync
```

### gen3 secrets decode $secretName [$secretKey]

Decode the specified kubernetes secret.

```
ex:
gen3 secrets decode fence-creds

ex2:
gen3 secrets decode fence-creds creds.json

```

