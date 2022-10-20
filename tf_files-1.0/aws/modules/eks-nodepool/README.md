# TL;DR

This module is intended to create a ASG attached to an existing EKS cluster with an already default ASG.

The primary usage for this module is to create an isolated pool for jupyter notebook. Any other kind of pool has not yet been tested.


## 1. QuickStart

Not a module to be ran independently. Must be ran along with the EKS module.

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
- [5. Considerations](#5-considerations)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

All variables in this module are mandatory, however, since it is not intended to be ran alone or independently, all variables are filled by the invoker module wich is the EKS module.

## 4. Variables

### 4.1 Required Variables

* `vpc_name` Name of the VPC we are working on.
* `ec2_keyname`  Existing SSH key in EC2 to deploy the workers with.
* `instance_type` type of instance.
* `users_policy` policy to apply to the workers.
* `nodepool`  name of the node pool you are giving.
* `eks_cluster_ca` encoded certificate for EKS communication.
* `eks_cluster_endpoint`  endpoint for EKS.
* `eks_private_subnets` list of cidr for private subneting.
* `control_plane_sg` security group for the control plane to talk to the workers.
* `default_nodepool_sg` Security group of the default pool. This hasn't been tested for additional pools other than jupyter, but theoretically you could create as many pools as you want.
* `bootstrap_script` Script to use to initialize the worker. Default value `bootstrap-2.0.0.sh`
* `kernel` If your bootstrap script requires another kernel, you could point to it with this variable. Available kernels will be in `gen3-kernels` bucket. Default value `N/A`
* `jupyter_worker_drive_size` size of the worker driver size. Default 30.
* `jupyter_asg_desired_capacity` How many workers you want in your jupyter autoscaling group. Default 0
* `jupyter_asg_max_size` The max number of workers you would allow your jupyter autoscaling group to grow. Default 10.
* `jupyter_asg_min_size` The min number of workers you would allow your jupyter autoscaling group to shrink. Default 0.


## 5. Considerations

* We are using AWS EKS ready AMIs, even though there might be other options out there, we are using this ones as for now, or at least until there are more mature solutions.
  Said AMIs uses amazon linux, which default user is `ec2-user`.

* If this module is ran over an already existing ASG (in other words updating existing EKS clusters) you may need to manually apply `aws-auth-cm.yaml`. The content of said file is outputed at the end of the run and it is also in a file that is created in a directory `*_output_eks` when you run `gen3 cd`.
