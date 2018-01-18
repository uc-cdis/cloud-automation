# TL;DR

Terraform rules for bringing up cloud resources in different stacks.  Use the [gen3](../gen3/README.md) 
helper scripts to simplify running terraform and other
devops tasks.

## Organization

We typically run terraform from a "state folder" where a local state for a particular VPC is saved, and reference one of the *tf_files/* subfolders to specify the cloud resources that make up the VPC, so something like this:

```
$ cd state/folder
$ terraform init --backend-config ./vars1.tfvars --backend-config ./vars2.tfvars ~/Code/cloud-automation/tf_files/SUBFOLDER
```

* tf_files/aws - rules for resources in an AWS commons VPC
* tf_files/configs - templates supporting tf_files/aws
* tf_files/aws_user_vpc - rules for resources in an AWS VPC for user VM's
* tf_files/modules - terraform modules that can be shared between different stacks

