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

### gen3 secrets rotate newdb $serviceName $dbname

NOTE: only do this when allocating a new database via db-restore
or db-reset or similar.  This script does not change the OWNER
of the database tables or other artifacts, so things like `ALTER TABLE ...`
do not work due to postgres' idiosyncratic permissions system.

Create a new user with a new password, and GRANT ALL permissions
to the new user on $dbname. 
Outputs the `gen3 db creds` for the new user.

### gen3 secrets rotate postgres $serviceName

NOTE: schedule a maintenance window to rotate a service's db password.

Rotate the postgres password associated with the given service, and update the
`Gen3Secrets/` folder to use the new credentials.
Currently only supports the `indexd`, `sheepdog`, and `fence` services.

```
ex:
gen3 secrets rotate postgres indexd
cd $(gen3_secrets_folder)
git diff -w
gen3 secrets sync 'rotate indexd postgres creds'
gen3 roll indexd
```

### gen3 secrets revoke postgres $serviceName $oldUserName

Revoke permissions on the given service's database from the given postgres user role.
```
ex:
gen3 secrets revoke postgres indexd indexd_old_user
# if the old indexd_user is no longer needed, then drop it
server="$(gen3 db creds indexd | jq -r .g3FarmServer)"
gen3 psql $server -c 'DROP USER indexd_old_user;'
```
