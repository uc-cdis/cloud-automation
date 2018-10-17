# TL;DR

This module would bring up a fully functional EKS cluster. If everything goes as expected, then you should be able to run kubectl commands against the cluster.


## 1. QuickStart

```
gen3 workon <profile> <commons_name>_eks
```

Ex.
```
$ gen3 workon cdistest fauziv1_ks
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
fauziv1@cdistest_admin ~ % cat .local/share/gen3/cdistest/fauziv1_eks/config.tfvars 
vpc_name   = "fauziv1"
ec2_keyname = "fauziv1_automation_dev"
users_policy = "fauziv1"
```

## 4. Variables 

### 4.1 Required Variables 

* `vpc_name` usually the same name as the commons, this VPC must be an existing one, otherwise the execution will fail. Additioanlly, it worth mentioning that logging and VPC must exist before running this.
* `ec2_keyname` and existing key pair so we can ssh into the worker nodes. There might be a better way to achieve this, but as for now the key should exist. At the end, we replace the keys for what we put in terraform.
* `users_policy` This is the policy that was created before that allows the cluster to access the users bucket in bionimbus. Usually the same name as the VPC, but not always. 
   You may want to look up the policy in AWS console. It should something like `bucket_reader_cdis-gen3-users_fauziv1` the part you need to set the value of `users_policy` is just the part that differentiates the commons. In this case `fauziv1`

### 4.2 Optional Variables

* `instance_type` By default this is set to t2.medium, but it can be changed if needed.
* `csoc_cidr` By default set to 10.128.0.0/20.


## 5. Considerations 

* We are using AWS EKS ready AMIs, even though there might be other options out there, we are using this ones as for now, or at least until there are more mature solutions. 
  Said AMIs uses amazon linux, which default user is `ec2-user`.

* When tfapply is ran, there will be two main outputs `config_map_aws_auth` and `kubeconfig`. 
  `config_map_aws_auth` is a confimap that sets permision to the cluster to incorporate the worker nodes into the cluster. This is applied automatically, but in case it doesn't copy this output and apply it to the cluster. 
  `kubeconfig` is the config file for kubernetes, it is not saved automatically in the right path, therfore you must put it where your KUBECONFIG var points to.

   These outputs are also saved into a file in the terraform space. You can access it by running `gen3 cd`, there is a `<commons-name>_output_eks` folder which contains the files in question.

