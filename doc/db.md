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
