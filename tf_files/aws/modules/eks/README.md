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
- [5. Considerations](#5-considerations)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex.
```
fauziv1@cdistest_admin ~ % cat .local/share/gen3/cdistest/test-commons_eks/config.tfvars
vpc_name   = "test-commons"
ec2_keyname = "test-commons_automation_dev"
users_policy = "test-commons"
```

## 4. Variables

### 4.1 Required Variables

* `vpc_name` usually the same name as the commons, this VPC must be an existing one, otherwise the execution will fail. Additionally, it worth mentioning that logging and VPC must exist before running this.
* `ec2_keyname` and existing key pair so we can ssh into the worker nodes. There might be a better way to achieve this, but as for now the key should exist. At the end, we replace the keys for what we put in terraform.
* `users_policy` This is the policy that was created before that allows the cluster to access the users bucket in bionimbus. Usually the same name as the VPC, but not always.
   You may want to look up the policy in AWS console. It should something like `bucket_reader_cdis-gen3-users_fauziv1` the part you need to set the value of `users_policy` is just the part that differentiates the commons. In this case `fauziv1`

### 4.2 Optional Variables

* `instance_type` Instance_type for workers by default this is set to t3.large, but it can be changed if needed.
* `csoc_cidr` By default set to 10.128.0.0/20.
* `eks_version` Version of kubernetes to deploy for EKS, default is set to 1.10.
* `worker_drive_size` Size of the root volume for the workers. Default is set to 30 GB.
* `jupyter_instance_type` Instance_type for nodepool by default this is set to t3.medium, but it can be changed if needed.
* `bootstrap_script` Script to use to initialize the worker nodes. Default value `bootstrap-2.0.0.sh`.
* `jupyter_bootstrap_script` Script to intialize jupyter worekers. Default value `bootstrap-2.0.0.sh`.
* `kernel` If your bootstrap script requires a different kernel that what ships with the AMIs. Additionally, kernels will be uploaded onto `gen3-kernels` bucket in the CSOC account. Default value `"N/A"`.
* `jupyter_worker_drive_size` Size of the jupyter workers drive. Default 30.
* `cidrs_to_route_to_gw` CIDRs you would like to get out skiping the proxy. This var should be a list type, Ex: `cidrs_to_route_to_gw = ["192.170.230.192/26", "192.170.230.160/27"]`. Default, empty list.
* `csoc_manged` If you want your commons attached to a CSOC accunt, just set the value of this one as "Yes", exactly like that. Any other value would be taken as no. Default is "Yes".
* `peering_cidr` Basically the CIDR of the vpc your adminVM belongs to. Since the above variable default is "Yes" this variable default is PlanX CSOC account.
* `jupyter_asg_desired_capacity` How many workers you want in your jupyter autoscaling group. Default 0
* `jupyter_asg_max_size` The max number of workers you would allow your jupyter autoscaling group to grow. Default 10.
* `jupyter_asg_min_size` The min number of workers you would allow your jupyter autoscaling group to shrink. Default 0.
* `iam-serviceaccount` If you wish to enable iam/service account to your cluster, useful for permissions. Default false.

#   After introducing HA-proxy

* `squid_image_name_search_criteria` Search criteria for the AMI that would serve as image base for squid instances. Default: `ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*`
* `squid_instance_drive_size` Size of the root volume of the squid instances.

## 5. Considerations

* We are using AWS EKS ready AMIs, even though there might be other options out there, we are using this ones as for now, or at least until there are more mature solutions.
  Said AMIs uses amazon linux, which default user is `ec2-user`.

* When tfapply is ran, there will be two main outputs `config_map_aws_auth` and `kubeconfig`.
  `config_map_aws_auth` is a configmap that sets permission to the cluster to incorporate the worker nodes into the cluster. This is applied automatically, but in case it doesn't copy this output and apply it to the cluster.
  `kubeconfig` is the config file for kubernetes, it is not saved automatically in the right path, therefore you must put it where your KUBECONFIG var points to.

   These outputs are also saved into a file in the terraform space. You can access it by running `gen3 cd`, there is a `<commons-name>_output_eks` folder which contains the files in question.

* `iam-serviceaccount` should only be used with EKS 1.13+, if you are running 1.12 or bellow, you must upgrade first, also you won't be able to enable on the same run when you are upgrading. Upgrade must come first.
