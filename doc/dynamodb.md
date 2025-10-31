# TL;DR

Helpers for interacting with the ACCESS dynamodb's

## Overview

ACCESS uses dynamodb and we want to be able to easily
interact with the tables created.

## Use

### gen3 dynamodb list-backups (table prefix)

Lists the dynamodb backups for a specific prefix. Can optionally give the table prefix if you don't want to interactively choose.

``` bash
ex:
gen3 dynamodb list-backups internalstaging
```

### gen3 dynamodb create-backup (table prefix)

Creates timestamped backups for all dynamodb tables with specific prefix.

``` bash
ex: 
gen3 dynamodb create-backup internalstaging
```

### gen3 dynamodb restore (table prefix)

Restores dynamodb tables matching a specific timestamp and prefix.

``` bash
ex:
gen3 dynamodb restore internalstaging
```

### gen3 dynamodb help

Shows help page

``` bash
ex:
gen3 dynamodb help
```
