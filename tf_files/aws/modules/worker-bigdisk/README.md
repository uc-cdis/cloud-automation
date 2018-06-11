# TL;DR

bigdisk module is intended to create an AWS volume and attached to the specified instance.


# 1. Quickstart

`gen3 workon <account> <vmname>_bigdisk`


# 2. Table of Contents

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)


# 3. Overview

Once you workon the workspace, you must edit config.tfvars accordingly.

Ex:

```
ubuntu@csoc_admin:~/cloud-automation$ cat ../.local/share/gen3/csoc/revproxy_bigdisk/config.tfvars 
volume_size = 20
instance_ip = "10.128.2.108"
dev_name = "/dev/sdz"
```

# 4. Variables

* volume_size: the size of the new drive in GiB
* instance_ip: ip of the VM that you want the volumen attached to.
* dev_name: in case you want to attach a second or third drive to the same instance, change this accordingly.

