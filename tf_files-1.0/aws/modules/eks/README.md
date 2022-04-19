# TL;DR

This module would bring up a fully functional EKS cluster. If everything goes as expected, then you should be able to run kubectl commands against the cluster.


## 1. QuickStart

```
gen3 workon <profile> <commons_name>_eks
```

Ex.
```
$ gen3 workon cdistest test-commons_eks
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
- [7. Adding a Secondary Subnet](#7-adding-a-seconday-subnet)


## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex.
```
generic-commons@cdistest_admin ~ % cat .local/share/gen3/cdistest/test-commons_eks/config.tfvars
vpc_name   = "test-commons"
ec2_keyname = "test-commons_automation_dev"
users_policy = "test-commons"
```

## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| vpc_name | Usually the same name as the commons. This VPC must exists arelady otherwise, the execution will fail. Additionally, it worth mentioning that logging and vpc must esist before running this. | string | n/a |
| ec2_keyname | An existing key pair in EC2 that we want in the k8s worker nodes. | string | n/a |
| users_policy | This is the policy that was created before that allows the cluster to access the users bucket in bionimbus. Usually the same name as the VPC, but not always. | string | n/a |


### 4.2 Optional Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| instance_type | For k8s workers | string | t3.large |
| peering_cidr | CIDR were your adminVM belongs to. | string | 10.128.0.0/20 |
| eks_version | Version for EKS cluster | string | 1.14 |
| availability_zones | AZs where to deploy the kubernetes worker nodes. Could be automated. | list |  ["us-east-1a","us-east-1d","us-east-1d"] |
| worker_drive_size | Volume size for the k8s workers | string | 30GB |
| jupyter_instance_type | For k8s jupyter workers | string | t3.medium |
| workflow_instance_type | For k8s workflow workers | string | t3.2xlarge |
| bootstrap_script | Script to initialize the workers | string | [bootstrap.sh](https://github.com/uc-cdis/cloud-automation/tree/master/flavors/eks) |
| jupyter_bootstrap_script | Script to initialize the jupyter workers | string | [bootstrap.sh](https://github.com/uc-cdis/cloud-automation/tree/master/flavors/eks) |
| jupyter_worker_drive_size | Drive Size for jupyter workers | string | 30GB |
| peering_cidr | AdminVM's CIDR for peering connections | string | 10.128.0.0/20 (PlanX CSOC) |
| jupyter_asg_desired_capacity | # of jupyter workers | number | 0 |
| jupyter_asg_max_size | Max # of jupyter workers | number | 10 |
| jupyter_asg_min_size | Min # of jupyter workers | number | 0 |
| workflow_asg_desired_capacity | # of jupyter workers | number | 0 |
| workflow_asg_max_size | Max # of jupyter workers | number | 50 |
| workflow_asg_min_size | Min # of jupyter workers | number | 0 |
| iam-serviceaccount | iam/service account to your cluster | boolean | false |
| cidrs_to_route_to_gw | CIDR you want to skip the proxy when going out | list | [] |
| workers_subnet_size | Whether you want your workers on a /24 or /23 subnet, /22 is available, but the VPC module should have been deployed using the `network_expansion = true` variable, otherwise wks will fail | number | 24 |
| oidc_eks_thumbprint | OIDC to use for service account intergration | string | \<AWS DEFAULT\> |
| domain_test | If ha-proxy a domain to check internet access | string | gen3.io |
| ha_squid | If enabled, this should be set to true | boolean | false |
| dual_proxy | If migrating from single to ha, set to true, should not disrrupt connectivity | boolean | false |
| sns_topic_arn | SNS topic ARN for alerts | string | "arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-topic" |
| secondary_cidr_block | A secondary CIDR range that will get allocated the the workflow autoscaling group | string | "" |

## 5. Outputs

| Name | Description | 
|------|-------------|
| kubeconfig | kubeconfig file to talk to kubernetes |
| config_map_aws_auth | configmap that sets permissions to incorporate the worker nodes into the cluster |


## 6. Considerations

* We are using AWS EKS ready AMIs, even though there might be other options out there, we are using these ones as for now.

Said AMIs uses amazon linux, which default user is `ec2-user`.

* When tfapply is ran, there will be two outputs `config_map_aws_auth` and `kubeconfig`.

`config_map_aws_auth` is a configmap that sets permissions to incorporate the worker nodes into the cluster. This is applied automatically, but in case it doesn't, copy this output and apply it to the cluster.
`kubeconfig` is the config file for kubernetes, it is not saved automatically in the right path, therefore you must put it where your KUBECONFIG var points to.

These outputs are also saved into a file in terraform space. You can access it by running `gen3 cd`, there is a `<commons-name>_output_eks` folder that  contains the files in question.

* `iam-serviceaccount` must only be used with EKS 1.13+, if you are running 1.12 or bellow, you must upgrade first. Additionally, you won't be able to enable this on the same run for upgrading out of 1.12. Upgrade must come first.

## 7. Adding a Secondary subnet

If you are running workflow nodes and running into IP exhaustion issues, you can add a secondary CIDR range to create a new subnet for the workflow nodes to run in. You will need to add/run it in the VPC/commons module and then here, as the VPC/commons module will attach the new CIDR range to the VPC, and this module will update the autoscaling groups to use it. Some functionality, like checking logs, will not work for up to 4 hours after the change, as the EKS api needs to run a job to refresh the whitelisted CIDR ranges. However, the pods should still be able to come up and work as usual during this time.
