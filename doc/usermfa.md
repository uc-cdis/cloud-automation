# TL;DR

Add a user to a VM with MFA configured

## Overview

See https://github.com/uc-cdis/cdis-wiki/blob/master/ops/onCall/Library/SshStuff.md for how to configure a VM ssh with MFA.

The setup is we have a public VM with ssh access, and we want to add users to the VM with ssh authorized keys and MFA setup.


## Use

### gen3 usermfa add userFolder/ mfaHostLabel

The input is a user folder:
```
userFolder/
    info.json
    authorized_keys
```

The `mfaHostLabel` argument is either the IP address or hostname
at which the user accesses the VM.

Ex:
```
gen3 usermfa frickjack/ host.name
```

Note that the `authorized_keys` file only accepts `openssh` format public keys: https://tutorialinux.com/convert-ssh2-openssh/

### gen3 usermfa qr label secret

Wrapper around qr-encode - outputs

```
gen3 usermfa 'frickjack@vmname' 'secret secret bla bla' > frickjackMfaQr.png
```

### gen3 usermfa testsuite

Run a test suite - not yet integrated with `gen3 test suite` -
creates (and deletes on success) a unix user and requires sudo

```
gen3 usermfa testsuite
```
