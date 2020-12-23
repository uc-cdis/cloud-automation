# TL;DR

Core module to stand up commons with cloud-automation.


## 1. QuickStart

This module is intended to be part of the VPC module and not to be called by itself. Nonetheless it could work on its own.

```
gen3 workon <profile> <commons-mane>
```

Ex:

```bash
gen3 workon cdistest generic-commons
```


## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Considerations](#5-considerations)


## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.



## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| vpc_name | Name you will give to the commons | string | whatever is used as \<commons-name\> when `workon` |
| peering_cidr | CIDR of the VPC you want to peer to (adminVM's cidr usually) | string | 10.128.0.0/20 |
| csoc_managed | If your commons is part of a managed account | boolean | true |
| peering_vpc_id | VPC id of the one you want peered with the cluster's | string | vpc-e2b51d99 |
| vpc_cidr_block | CIDR to be used by the cluster's resources | string | 172.24.17.0/20 | 
| availability_zones | AZs for the cluster | list | ["us-east-1a", "us-east-1c", "us-east-1d"] |


### 4.2 Optional Variables 

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| csoc_account_id | If it is part of a centrilized account then put the id here | string | 433568766270|
| ami_account_id | AMI to be used for the proxy | string | 707767160287 |
| organization_name | For tag purposes | string | Basic Service |
| squid_image_search_criteria | Search criteria for HA squid AMI look up | string | ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server- |
| squid_instance_drive_size | Volume size for the HA squid instance | string | 8GB |
| squid_instance_type | Instance type for HA squid instances | string | t3.medium | 
| squid_bootstrap_script | Script to run on deployment for the HA squid instances | string | squid_running_on_docker.sh |
| deploy_single_proxy | If you don't want squid HA then set this to true | boolean | true |
| squid_extra_vars | Additional variables to pass along with the bootstrapscript | list | [] |
| fence-bot_bucket_access_arns | If fence user needs to access an additional bucket as to what's created in this module | list | [] |
| deploy_ha_squid | If you want the HA squid cluster | boolean | false |
| squid_cluster_desired_capasity | If ha squid is enabled and you want to set your own capasity | int | 2 | 
| squid_cluster_min_size | If ha squid is enabled and you want to set your own min size | int | 1 |
| squid_cluster_max_size | If ha squid is enabled and you want to set your own max size | int | 3 | 
| branch | For development purposes only | string | master |



## 5. Output

| Name | Description |
|------|-------------|
| zone_id | Route53 zone id for internal.io |
| zone_name | Route53 zone name |
| vpc_id | VPC Id created |
| vpc_cidr_block | VPC CIDR block |
| public_route_table_id | Reoute table id | 
| gateway_id | Internet gateway id |
| public_subnet_id | Subnet with public access |
| security_group_local_id | Sec Group id for the "local" rule |
| nat_gw_id | Nat gateway id |
| ssh_key_name | SSH key used |
| vpc_peering_id | VPC peering id |
| es_user_key | key for ES access |
| es_user_key_id | secret for ES access |
| cwlogs | log group used for logging |
| fence-bot_id | Fence bot user ID |
| fence-bot_secret | fence bot user secret |
| data-bucket_name | Data bucket name |
