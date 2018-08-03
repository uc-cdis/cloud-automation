# TL;DR

This module is still on it first steps, but it is intended to build up a fully functional kubernetes cluster on EKS.


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
```

## 4. Variables 

### 4.1 Required Variables 

* `vpc_name` usually the same name as the commons, this VPC must be an existing one, otherwise the execution will fail. Additioanlly, it worth mentioning that logging and VPC must exist before running this.
* `ec2_keyname` and existing key pair so we can ssh into the worker nodes. There might be a better way to achieve this.

### 4.2 Optional Variables

* `instance_type` By default this is set to t2.medium, but it can be changed if needed.
* `csoc_cidr` By default set to 10.128.0.0/20.


## 5. Considerations 

* We are using AWS EKS ready AMIs, even though there might be other options out there, we are using this ones as for now, or at least until there are more mature solutions. 
  Said AMIs uses amazon linux, which default user is `ec2-user`. We are enabling root logging to the instances for the keys we are pasting in there.

* When tfapply is ran, there will be two main outputs `config_map_aws_auth` and `kubeconfig`. You must copy the output and put them in files accordingly. Both are in YAML format. 
  The first one is an authentication configmap that will allow the k8s cluster add the nodes into it, otherewise you won't see the nodes at all.
  The second one is the kubeconfig file to use.

* Due to the fact that you need to use keys to access EKS endpoint, we need to re-design gen3 later in order to be able to use this out of the box.
  As for now, you may use `gen3 arun` or set ENV varaibles with valid key, the ones that gen3 genenerates `gen3 arun env | grep AWS`.

Finally, examples:


```
fauziv1@cdistest_admin ~ % gen3 arun kubectl apply -f aws-auth-cm.yaml --kubeconfig kubeconfig-FauziEKSTest               
configmap/aws-auth created

fauziv1@cdistest_admin ~ % gen3 arun kubectl get node
NAME                            STATUS    ROLES     AGE       VERSION
ip-172-24-50-107.ec2.internal   Ready     master    20d       v1.9.3
ip-172-24-50-21.ec2.internal    Ready     node      20d       v1.9.3
ip-172-24-50-80.ec2.internal    Ready     node      20d       v1.9.3

fauziv1@cdistest_admin ~ % gen3 arun kubectl --kubeconfig kubeconfig-FauziEKSTest run nginx --image nginx:latest -ti -- bash
If you don't see a command prompt, try pressing enter.

root@nginx-6d9b45cb59-r7zsh:/# exit
exit
Session ended, resume using 'kubectl attach nginx-6d9b45cb59-r7zsh -c nginx -i -t' command when the pod is running

fauziv1@cdistest_admin ~ % gen3 arun kubectl get pod --kubeconfig kubeconfig-FauziEKSTest
NAME                     READY     STATUS    RESTARTS   AGE
nginx-6d9b45cb59-r7zsh   1/1       Running   1          4m
```
