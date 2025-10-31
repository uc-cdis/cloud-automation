# TL;DR

Qualys VM in CSOC account.


## 1. QuickStart

```
gen3 workon csoc <qulays scanner vm name>_qualysvm
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Outputs](#5-outputs)
- [6. Considerations](#6-considerations)



## 3. Overview


Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex:
```
user_perscode              = "XXXXXXXXXXXXXX"
vm_name                    = "CTDS-AWS-CSOC-VIRT1"
image_name_search_criteria = ""
image_desc_search_criteria = "Qualys(R) Virtual Scanner Appliance (HVM EBS) for AWS pre-authorized scanning"
env_vpc_subnet             = "10.128.8.224/27"
ssh_key_name               = "someone@uchicago.edu"
```



## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| vm_name | Name you are giving to the VM when deployed | string | |
| user_perscode | Qualys registration code | string | "" | 



### 4.2 Optional Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| vpc_id | VPC id where the VM will live | string | "vpc-e2b51d99" |
| env_vpc_subnet | Subnet where the VM will be | string | "10.128.3.0/24" |
| qualys_pub_subnet_routetable_id | Route table to associate the VM with | string | "rtb-7ee06301" |
| ssh_key_name | Key pair associated with the VM. | string | "rarya_id_rsa" |
| image_name_search_criteria | Search criteria to search for AMI | string | "a04e299c-fb8e-4ee2-9a75-94b76cf20fb2" |
| image_desc_search_criteria | Search criteria to search for AMI | string | "" |
| ami_account_id | AWS Account id to filter the search of AMI | string | "679593333241" |
| organization | For tag purposes | string | PlanX |
| environment | For tag purposes | Environment for tag purposes | string | "CSOC" |
| instance_type | Instance type for the VM | string | "t3.medium" |


## 5. Outputs

| Name | Description |
|------|-------------|
| qualys_public_ip | public IP for the VM |
| qualys_private_ip | private IP for the VM |


## 6. Considerations
N/A
