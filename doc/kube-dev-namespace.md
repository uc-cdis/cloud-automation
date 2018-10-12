# TL;DR

Create a new Linux user on an adminvm configured to deploy a `gen3` commons to a kubernetes namespace with the same name.
Run this script on an admin-vm in a VPC user account with `sudo` permissions.

## Use

```
gen3 kube-dev-namespace $vpc_name $new_namespace_name
```
