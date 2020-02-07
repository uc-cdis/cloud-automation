# TL;DR
  
This module is intended to bring up a ha-squid environment comprised by at least two instances in an autoscaling group


## 1. QuickStart

This module is intended to be part of the VPC module and not to be called by itself. Nonetheless it could work on its own.

```
gen3 workon <profile> <commons-mane>_squidauto
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

Once you workon the workspace, you may want to edit the config.tfvars accordingly. To access the file more easily, try `gen3 cd`

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.


## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| env_vpc_cidr | CIDR of the VPC where this cluster will reside | string | n/a | yes |
| squid_proxy_subnet | Subnet where the instances will be | string | n/a | yes |
| env_vpc_name | Name of the VPC where the instances will be | string | n/a | yes |
| env_squid_name | Name of the squid cluster | string | n/a | yes |
| peering_cidr | This is the cird from where cloud-automation is being ran (adminVM) | string | n/a | yes |
| env_log_group | AWS CloudwatchLogs Group namd where logs will be sent  | string | n/a | yes |
| env_vpc_id | The vpc id where the proxy cluster will reside | string | n/a | yes |
| main_public_route | The route table that allows public access | string | n/a | yes |
| route_53_zone_id | DNS zone for .internal.io | string | n/a | yes |
| ssh_key_name | Key pair in EC2 | string | n/a | yes |
| squid_availability_zones | AZs where to deploy squid insances | list | n/a | yes |



### 4.2 Optional Variables



| Name | Description | Type | Default | Required |
| ami_account_id | AWS account id owner of the AMI to be used by squid | string | "099720109477" | no |
| image_name_search_criteria | Criteria to be used to search for AMIs in the account specified | string | "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-\*" | no |
| bootstrap_path | Folder that contains the bootstrapscript in cloud-automation | string | "cloud-automation/flavors/squid_auto/" | no |
| bootstrap_script | Script within the above folder | string | squidvm.sh | no |
| squid_instance_type | Instance type for squid instances  | string | t3.medium  | no |
| organization_name | For tagging purposes  | string | Basic Services  | no |
| squid_instance_drive_size| Volume size for the root partition  | integer | 8  | no |
| extra_vars | Additional information to be bassed on the bootstrap script | list | ["squid_image=master"] | no |
| deploy_ha_proxy | If to deploy this module | boolean | true | no |

