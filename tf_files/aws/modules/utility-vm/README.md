# TL;DR

UtilityVM is intended to make the spin up of new VMs more easily. The whole idea is to offload any package installation to a file within the cloud-automation folder.

Originally, modules would use a custom AMI created though Packer, although this is still a good practice, different issues arises, like keeping the image updated updated. 

The main advantage of this utilityVM module is the ability to add custom boostrap script without altering the user_data portion in terraform and also the custom script in the packer image creation.


## 1. QuickStart

```
gen3 workon csoc <commons account name>_utilityvm
```

## 2. Table of Contents 

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)

## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly 

Ex: 

`ubuntu@csoc_admin:~$ cat .local/share/gen3/csoc/test_utilityvm/config.tfvars 
bootstrap_path = "cloud-automation/flavors/nginx/"
bootstrap_script = "es_revproxy.sh"
vm_name = "test"
vm_hostname = "test"
vpc_cidr_list = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]
extra_vars = ["public_ip=35.174.124.219"]`

By default, when the VM comes up, it'll be placed in /home/ubuntu, therefore you want to provide the bootstrap_path accordingly, you could always use absolute paths nonetheless. 

vpc_cird_list would try to send traffic out of the NAT gateway directly.


## 4. Variables 


### 4.1 Required Variables

This variables would be initialized when you first `workon` the module. you need to update accordingly. 

* bootstrap_path: folder where the custom bootstrap script is located. Can be absolute or relative. If you want to use relative, keep in mind that you will be located in `/home/ubuntu`.
* bootstrap_script: strip to execute located at the path previously set.
* vm_name: how would you like the VM to be named. This is basically to identify the VM within AWS console (name and Name tag).
* vm_hostname: `hostnamectl set-hostname <vm_hostname>` would be execcuted in which would set the VM hostname. You can always change this later.
* vpc_cidr_list: list of cidrs that would overpass the proxy.
* extra_vars: in case you want to use some vars within the bootstrap script. Must be `;` separated if you want to provide more than one. You can leave the list empty.


### 4.2 Optional Variables 

This variables are not initialized but you can change them if needed.

* ami_account_id: by default we use `099720109477`, which is canonical's AWS account, they release updates frequenlty of their images.
* image_name_search_criteria: this is the criteria to search among images released by the account ID especified in ami_account_id. Default `ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018`.
* aws_account_id: the account ID of where the VM would be spun up. By default we use CSOC's.
* aws_region: region where the VM would be put on.
* vpc_id: self explanatory.
* vpc_subnet_id: subnet within vpc_id.
* ssh_key_name: this one will most likely be overwriten, but in case something goes wrong with the execution script, you might still be able to access the VM.
* environment: for tagging purposes.
* instance_type: t2.micro, t2.medium, etc.

