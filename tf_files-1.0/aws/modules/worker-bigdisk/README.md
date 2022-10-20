# TL;DR

bigdisk module is intended to create an AWS volume and attached to the specified instance.


# 1. Quickstart

`gen3 workon <account> <vmname>_bigdisk`


# 2. Table of Contents

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
- [5. Considerations](#5-considerations)


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
* instance_ip: ip of the VM that you want the volume attached to.
* dev_name: in case you want to attach a second or third drive to the same instance, change this accordingly.


# 5. Considerations

This particular module would only create the volume and attach it to the instance of your preference. It won't though, format it and mount it for you, as this is a OS operation that we can't tell terraform to perform for you.

How to proceed in this case? This is a simple example on how to. If you don't know how to format and mount, search for help.

Search for the drive with `lsblk`:

```
ubuntu@cdistest_admin:~$ sudo lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
xvda    202:0    0    8G  0 disk
--xvda1 202:1    0    8G  0 part /
xvdz    202:80   0  100G  0 disk
```

You could create a single partition with `fdisk`, `parted` or any other of your preference.


```
fdisk /dev/xvdz
```

Then format it, most likely you would want to use ext4.

```
mkfs.ext4 /dev/xvdz1
```

Then mount it

```
mount /dev/xvdz /newdrive
```

Remember to add it to `/etc/fstab`

