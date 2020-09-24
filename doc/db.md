# TL;DR

Helpers for interacting with the gen3 database server farm.

## Overview

We run a farm of one or more database servers on which we provision
the various databases used by gen3 services.

## Use

### gen3 db creds service

```
ex:
gen3 db creds fence
```

### gen3 db server list

Get the credentials associated with a farm server.

```
ex: 
gen3 db server info server1
```

### gen3 db server list

List the servers in the database farm.  Note that the server for the 
sheepdog and peregrine services is dedicated to those servers, and not
included in the list.

```
ex:
gen3 db server list
```

### gen3 db list

List the databases on a particular server

```
ex:
gen3 db list "server1"
```

### gen3 db psql

Same as `gen3 psql`

```
ex:
gen3 db psql server1

gen3 db psql fence
```

### gen3 db server list

List the servers in the db farm.

### gen3 db services

List the services with databases accessible via `gen3 db`

### gen3 db setup

Setup a database, db user, and associated secrets for the specified service.
NOOP if database already provisioned.

```
ex:
gen3 db setup "service_name"
```

The script randomly selects one of the `farmEnabled` farm servers by default, but 
a server name may optionally be added to the command line.

```
ex:
gen3 db setup "service_name" "server1"
```

### gen3 db snapshot list

List the RDS snapshots associated with a given server

```
ex:
gen3 db snapshot list server1
```

### gen3 db snapshot take [--dryrun]

Trigger a new db snapshot for the specific server.

```
ex:
gen3 db snapshot take server1
```

### gen3 db backup dbname

`pg_dump` the given database to stdout; the output is suitable for `gen3 db restore backup.file dbname`

### gen3 db restore dbname backup.file [--dryrun]

Create a new database on the same server as `dbname` owned by the `dbname` owner, and restore `backup.file` into it, and output the credentials to connect to the database.

```
ex:
gen3 db restore fence fence_20190101.backup
```

### gen3 db encrypt profile workspace

Used to encrypt the rds databases. You should use the profile/workspace from gen3 workon used to setup the vpc/rds. There is also an extra argument you can add to specify the directory to hold the db snapshots. This should be used for larger db's where the root volume is not large enough to store the snapshots. This will take care of updating the databases in the account you run it from but you will need to update the rds endpoints for any other namespaces. Once the new rds instances have been verified to be working you can manually delete them using the aws cli/console.

```bash
ex.
gen3 db encrypt cdistest emalinowskiv1 </mnt/extravolume>
```
