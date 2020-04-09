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

### gen3 secrets gcp $sub-command ...

helper for rotating GCP keys

#### gen3 secrets gcp rotate $keyfile

* the `$keyfile` argument is a sub-path under `Gen3Secrets/`
* garbage collect old keys associated with the keyfile (the newest key is left in place)
* create a new key, and save the new key into the file
* `gen3 secrets commit ...`

the caller is responsible updating the appropriate kubernetes secrets, and rotating services as required

ex:

```
gen3 secrets rotate apis_configs/fence_google_app_creds_secret.json
```

also accepts the service account key file as an argument

#### gen3 secrets gcp new-key $serviceAccountId

generate a new key for the given service account
you can list the currently available keys with:

```
gcloud iam service-accounts keys list --managed-by user --iam-account "$serviceAccountId" --format json --sort-by 'validAfterTime'
```

also accepts the service account key file as an argument

#### gen3 secrets gcp list $serviceAccountId

shortcut for:
```
gcloud iam service-accounts keys list --managed-by user --iam-account "$serviceAccountId" --format json --sort-by 'validAfterTime'
```

also accepts the service account key file as an argument

#### gen3 secrets gcp garbage-collect $serviceAccountId

delete all but the newest key for the given service account

also accepts the service account key file as an argument
