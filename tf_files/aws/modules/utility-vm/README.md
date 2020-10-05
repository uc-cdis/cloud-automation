# TL;DR

UtilityVM is intended to make the spin up of new VMs more easily. The whole idea is to offload any package installation to a file within the cloud-automation folder.

Originally, modules would use a custom AMI created though Packer, although this is still a good practice, different issues arises, like keeping the image updated updated.

The main advantage of this utilityVM module is the ability to add custom bootstrap script without altering the user_data portion in terraform and also the custom script in the packer image creation.

TODO: migrate this thing to deploy a chef role instead of a `flavor/` script ...

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

```
ubuntu@csoc_admin:~$ cat .local/share/gen3/csoc/test_utilityvm/config.tfvars
bootstrap_path = "cloud-automation/flavors/nginx/"
bootstrap_script = "es_revproxy.sh"
vm_name = "test"
vm_hostname = "test"
vpc_cidr_list = ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"]
extra_vars = ["public_ip=35.174.124.219"]
```

By default, when the VM comes up, it'll be placed in /home/ubuntu, therefore you want to provide the bootstrap_path accordingly, you could always use absolute paths nonetheless. 

vpc_cird_list would try to send traffic out of the NAT gateway directly.


## 4. Variables


### 4.1 Required Variables

This variables would be initialized when you first `workon` the module. They still need to be updated accordingly.

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| bootstrap_path | Folder where the bootstrap script is located. Can be absolute or relative. If you want to use relative, keep in mind that you will be located in `/home/ubuntu`. | string | "cloud-automat/flavor/" |
| bootstrap_script | Script o execute located at the path previously set. | string | "" |
| vm_name | Name you want for the VM | string | "" |
| vm_hotname | Hostname you want for the VM | string | "" | 
| vpc_cidr_list | List of CIDRs to overpass the proxy | list | ["10.128.0.0/20", "54.0.0.0/8", "52.0.0.0/8"] |


### 4.2 Optional Variables

This variables are not initialized but you can change them if needed.

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| ami_account_id | AWS account id to use for AMI search. | string | "099720109477" |
| image_name_search_criteria | Criteria to search among images released by the account ID specified in ami_account_id | string | "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2018" |
| aws_account_id | Account ID of where the VM would be spun up. By default we use CSOC's. | string | 433568766270 |
| aws_region | Region where the VM would be put on. | string | us-east-1 |
| vpc_subnet_id | Subnet within vpc_id. | string | "vpc_subnet_id" |
| ssh_key_name | This one will most likely be overwritten, but in case something goes wrong with the execution script, you might still be able to access the VM. | string | "fauzi@uchicago.edu" |
| environment | For tagging purposes | string | "CSOC" |
| instance_type | Self explanatory | string | t3.micro | 
| proxy | If the VM will be behind a proxy | boolean | yes |
| authorized_keys | Path to file containing ssh keys that will be copied to `/home/ubuntu/.ssh/authorized_keys`. | string | "files/authorized_keys/ops_team" |
| branch | For testing purposes | string | "master" |
| user_policy | additional policy for the role | string | "" |
