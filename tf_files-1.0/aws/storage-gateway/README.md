# TL;DR

Module to stand up storage gateway with cloud-automation.


## 1. QuickStart

This module is intended to be part of the VPC module and not to be called by itself. Nonetheless it could work on its own.

```
gen3 workon <profile> <commons-mane>__storage-gateway
```

Ex:

```bash
gen3 workon cdistest generic-commons__storage-gateway
```


## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)


## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly. This also uses the main commons template file, so ensure you remove the unnecessary variables, or at least the ones that will cause a syntax error.

Once the terraform is run you will need to add the ip to the noproxy list in your .bashrc file, you can find it from the output of the terraform run. From there you will want to connect to the storage gateway ip address. To connect you will need to make sure the key pair provided is your key pair, or one you have access to so you can ssh using your key, and connect to the admin user. Once connected, you need to setup the storage gateway to use the proxy, press 1, the type cloud-proxy.internal.io, then 3128 for the port. Once that is setup you should be able to rerun the terraform to let it finish.



## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| vpc_name | Name you will give to the commons | string | whatever is used as \<commons-name\> when `workon` |
| ami_id | The latest ami id of the storage gateway  | string | N/A |


### 4.2 Optional Variables 

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| size | The size of the storage gateway server | int | 80 |
| cache_size | AZs for the cluster | int | 150 |

