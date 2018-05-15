# TL;DR

UtilityVM is intended to make the spin up of VM more easily. The whole idea is to offload any package installation to a file within the cloud-automation folder 


## 1. QuickStart

```
gen3 workon csoc <commons account name>_utilityvm
```

## 2. Table of Contents 

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)


## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly 

Ex: 

`ubuntu@csoc_admin:~$ cat .local/share/gen3/csoc/nginx_utilityvm/config.tfvars 
bootstrap_path = "cloud-automation/flavors/nginx/"
bootstrap_script = "es_revproxy.sh"
vm_name = "csoc_nginx_server"
vm_hostname = "csoc_nginx_server"
vpc_cidr_list = []
`

By default, when the VM comes up, it'll be placed in /home/ubuntu, therefore you want to provide the path accordingly. vpc_cird_list would try to send traffic out of the NAT gateway directly.

