# TL;DR

Helpers that handles a few squid related tasks


## Use

### swap

Would change the current active instance to a different one.

NOTE: this is intended to be used on HA squid enabled environments only.

```bash
gen3 squid swap
```

#### variant

The original script was written on python and might no be gen3 friendly, if you would like outputs more aligned with gen3 try the following:

```bash
gen3 squid swap bash
```

