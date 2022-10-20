# TL;DR
  
This module is intended to bring up a ha-squid environment comprised by at least two instances in an autoscaling group

## 1. QuickStart

This module is intended to be part of the VPC module and not to be called by itself. Nonetheless it could work on its own.

```bash
gen3 workon <profile> <commons-mane>_squidauto
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Output](#5-output)

## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly. To access the file more easily, try `gen3 cd`

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| env_vpc_cidr | CIDR of the VPC where this cluster will reside | string | n/a |
| squid_proxy_subnet | Subnet where the instances will be | string | n/a |
| env_vpc_name | Name of the VPC where the instances will be | string | n/a |
| env_squid_name | Name of the squid cluster | string | n/a |
| peering_cidr | This is the cird from where cloud-automation is being ran (adminVM) | string | n/a |
| env_log_group | AWS CloudwatchLogs Group namd where logs will be sent  | string | n/a |
| env_vpc_id | The vpc id where the proxy cluster will reside | string | n/a |
| main_public_route | The route table that allows public access | string | n/a |
| route_53_zone_id | DNS zone for .internal.io | string | n/a |
| ssh_key_name | Key pair in EC2 | string | n/a |
| squid_availability_zones | AZs where to deploy squid insances | list | n/a |

### 4.2 Optional Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| ami_account_id | AWS account id owner of the AMI to be used by squid | string | "099720109477" |
| image_name_search_criteria | Criteria to be used to search for AMIs in the account specified | string | "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-\*" |
| bootstrap_path | Folder that contains the bootstrapscript in cloud-automation | string | "cloud-automation/flavors/squid_auto/" |
| bootstrap_script | Script within the above folder | string | [squid_running_on_docker.sh](https://github.com/uc-cdis/cloud-automation/tree/master/flavors/squid_auto) |
| squid_instance_type | Instance type for squid instances  | string | t3.medium  |
| organization_name | For tagging purposes  | string | Basic Services  |
| squid_instance_drive_size | Volume size for the root partition  | integer | 8 |
| extra_vars | Additional information to be bassed on the bootstrap script | list | ["squid_image=master"] |
| deploy_ha_squid | If to deploy this module | boolean | true |

### 5. Output

| Name | Description |
|------|-------------|
|      |             |
