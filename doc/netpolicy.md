# TL;DR

Helpers for generating procedural network policies.

## Overview

Mostly used by `kube-setup-networkpolicy`.
This is a great resource: https://github.com/ahmetb/kubernetes-network-policy-recipes


## Use

### gen3 netpolicy cidr $name $cidr1 $cidr2 ...

Generate a `$name` which allows pods to communicate with given CIDRs - the caller must add
a `podSelector` to the generated policy.

```
gen3 netpolicy cidr networkpolicy-frickjack 33.22.11.10 33.22.11.11 | jq -r -e '.spec.podSelector = { "matchLabels": { "frickjack":"yes" } }'
```

### gen3 netpolicy external

Generates `networkpolicy-external-egress` which allows pods labeled with `internet=yes` to communicate with the external internet, but does not allow access to `10/8`, `172.16/12`, or `169.254/16`.

```
gen3 netpolicy external
```

### gen3 netpolicy s3

Generates `networkpolicy-s3` which allows pods labeled with `s3=yes` to communicate with the S3 CIDR prefixes.

```
gen3 netpolicy s3
```

### gen3 netpolicy db

Generates `networkpolicy-db${serviceName}` which allows pods labeled with `app=$serviceName` to communicate with the `gen3 db $serviceName` database.

```
gen3 netpolicy db fence
```

### gen3 netpolicy bydb

Generates `networkpolicy-db${serviceName}-bydb` which allows pods labeled with `db${serviceName}=yes` to communicate with the `gen3 db $serviceName` database.

```
gen3 netpolicy bydb fence
```

### gen3 netpolicy isIp $addr

Little helper to verify that a string looks like an IP4 address - ex:
```
gen3 netpolicy isIp $addrStr && echo "$addrStr is an IP address"
```

