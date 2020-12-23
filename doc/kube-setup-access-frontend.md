# TL;DR

Used to setup ACCESS Frontend

## Overview

This is a script to setup the ACCESS Frontend. It can be used to setup a new frontend, modify an existing one or delete an already deployed one.

## Use

### gen3 kube-setup-access-frontend create

```
ex:
gen3 kube-setup-access-frontend create "url" "cert arn" "access-backend url" "access-backend client id"
```

### gen3 kube-setup-access-frontend update

Get the credentials associated with a farm server.

```
ex: 
gen3 kube-setup-access-frontend update "url" "access-backend url" "access-backend client id"
```

### gen3 kube-setup-access-frontend delete

```
ex:
gen3 kube-setup-access-frontend delete