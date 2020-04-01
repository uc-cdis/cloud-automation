# TL;DR

This procedure is intended to show steps required to migrate from a single Squid proxy instance, to an HA/Multizone one.

## Table of content

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
- [Procedure](#procedure)
  - [1. Update the VPC module](#1-update-the-vpc-module)
  - [2. Update the EKS module](#2-update-the-eks-module)
  - [3. Removing the single proxy instance route](#3-removing-the-single-proxy-instance-route)
  - [4. Remove the squid single instance](#4-remove-the-squid-single-instance)
- [Considerations](#considerations)
- [Extras](#extras)



## Overview

Currently, commons' Kubernetes clusters are using a single squid proxy to access the internet. Even though it works just fine in most cases, sometimes it fails, or the underlaying hardware fails and consequently AWS sets it for decomision, or the instance volume fills up all the sudden, among others. Furthermore, the AMI used as image base was created with Packer and tailored for the needs by that time.

The new HA model will now use official Canonical Ubuntu's 18.04 image and can be easily told to check for the latest release by them. This leaves the burden of keeping the instance updated and frequently checking on its health.

Logs are sent over to cloudwatch for historical data. Therefore, instances are disposable.

Keeping at least two instances always up, one as active and the second as standby, would decrease the amount of time commons are left out of internet access in the case of an event involving any of the instances. The standby instance would come in place if the active one fails for whatever reason. A lambda function will check for http access, from within the very same VPC where the commons lives, and port 3128 on each individual instance. Should those two succeed, then the proxy is switched to the stand by consequently becoming the active one.

The switching happens at the network level, the default route for kubernetes workers is an instance's ENI in the autoscaling group that manages the squid cluster. If http access fails, then each instance in squid autoscaling group is checked on port 3128, the first one that works is set as the new active.

This new module, or addition, has been thought to be optional. You can decide to keep the single instance model or switch to HA. If you don't want to incurd in additional charged that represents keeping an standby EC2 instance, then you can always set the cluster min and desired size of 1. The HA design, in any model, is advised over the old single instance deployment.



## Procedure

The procedure has been broken down to two options. One would deploy HA-squid on top of the single instance, meaning they'll run simultaenously. The second, would just destroy the single instance one and deploy HA alone.

The first option would mean little to no downltime, but would require more resources deployed at some point in time, which might mean of higher bills.

The second option is intended for non critical environments as it might leave the kubernetes worker nodes without internet access while the HA squid instances come up. Which could take up to 30 mins, depending on the case and the instance type selected.

It worth noting than for the first option, you could destroy the single instance model once you know HA is in place. The best way to determine if it is, is to check on the default gateway for the route table for `private_kube` and `eks_private`, both should be pointing to an ENI belonging to an instance in the HA squid cluster.

The following steps would show what needs to be done in order to deploy HA-squid in your commons.



### 1. Update the VPC module

Note: All these steps showed here were done on a deployment that runed on the latest master prior ha squid was introduced, the amount of resources terraform would need to add/modify/destroy might differ for each environment. Proceed with precausion.

Also, this guide will go through a parallel deployent of squid instances, and then removal of the single instance. This way, the amount of time the a cluster won't have internet access gets reduced to maximun a minute, which is the frequency lambda runs and checks.




Start by working on the module:

```bash
gen3 workon cdistest generic-commons
gen3 cd
```

After accessing the module configuration folder, we need to terraform taint a particular resorce othewise, terraform might fail later. There is a route table creation that used to come already populated with routes that will now be deployed empty and routes will be added accordingly.

The route for the default gateway is now dynamic and will be handled by a lambda function, depending on which becomes the active one.

Before you move on, you can try opening a devterm (`gen3 devterm`) and run the following:

```bash 
for i in {1..500}; do curl http://ifconfig.io --connect-timeout 1; sleep 5; done
```

The above command would try accessing the url passed along, it is usefull to check network continuity throught the implementation.


```bash
gen3 tform taint aws_route_table.private_kube
```


Tell terraform you want to deploy HA squid in config.tfvars


```bash
deploy_ha_squid = true
```


When the resource is tainted, you may proceed as you would regularly do. The plan to be created may want to delete a few resources, that's alright, it is inteded.

```bash
gen3 tfplan
```

The plan should show the following changes:

Tainted resources:

```bash
-/+ destroy and then create replacement
-/+ aws_route_table.private_kube (tainted) (new resource required)
```


Add:

```bash
  + create
  + aws_route.for_peering
  + module.cdis_vpc.module.squid-auto.aws_autoscaling_group.squid_auto
  + module.cdis_vpc.module.squid-auto.aws_iam_instance_profile.squid-auto_role_profile
  + module.cdis_vpc.module.squid-auto.aws_iam_role.squid-auto_role
  + module.cdis_vpc.module.squid-auto.aws_iam_role_policy.squid_policy
  + module.cdis_vpc.module.squid-auto.aws_launch_configuration.squid_auto
  + module.cdis_vpc.module.squid-auto.aws_route_table_association.squid_auto0[0]
  + module.cdis_vpc.module.squid-auto.aws_route_table_association.squid_auto0[1]
  + module.cdis_vpc.module.squid-auto.aws_route_table_association.squid_auto0[2]
  + module.cdis_vpc.module.squid-auto.aws_security_group.squidauto_in
  + module.cdis_vpc.module.squid-auto.aws_security_group.squidauto_out
  + module.cdis_vpc.module.squid-auto.aws_subnet.squid_pub0[0]
  + module.cdis_vpc.module.squid-auto.aws_subnet.squid_pub0[1]
  + module.cdis_vpc.module.squid-auto.aws_subnet.squid_pub0[2]
  + module.cdis_vpc.module.squid_proxy.aws_iam_instance_profile.cluster_logging_cloudwatch
  + module.cdis_vpc.module.squid_proxy.aws_iam_role.cluster_logging_cloudwatch
  + module.cdis_vpc.module.squid_proxy.aws_iam_role_policy.cluster_logging_cloudwatch
  + module.cdis_vpc.module.squid_proxy.aws_route53_record.squid
```


Modify:

```bash
  ~ update in-place
  ~ aws_route_table_association.private_kube
  ~ module.cdis_vpc.aws_default_route_table.default
  ~ module.cdis_vpc.aws_eip.nat_gw
  ~ module.cdis_vpc.aws_iam_user.es_user
  ~ module.cdis_vpc.aws_internet_gateway.gw
  ~ module.cdis_vpc.aws_nat_gateway.nat_gw
  ~ module.cdis_vpc.aws_security_group.local
  ~ module.cdis_vpc.aws_security_group.out
  ~ module.cdis_vpc.aws_vpc_peering_connection.vpcpeering
  ~ module.elb_logs.aws_s3_bucket.log_bucket
```


Destroy:

```bash
  - destroy
  - aws_security_group.kube-worker
  - aws_vpc_endpoint.k8s-s3
  - module.cdis_vpc.aws_ami_copy.login_ami
  - module.cdis_vpc.aws_iam_instance_profile.cluster_logging_cloudwatch
  - module.cdis_vpc.aws_iam_role.cluster_logging_cloudwatch
  - module.cdis_vpc.aws_iam_role_policy.cluster_logging_cloudwatch
  - module.cdis_vpc.aws_route53_record.squid
  - module.cdis_vpc.aws_security_group.webservice
```


Terraform will perform the following actions:

```bash
Plan: 19 to add, 10 to change, 9 to destroy.
```

If it doesn't look like above, make sure the no harm will be done to production clusters. Then apply the plan.


```bash
gen3 tfapply
```

Sometimes terraform might fail applying a plan due to different reasons, you can run the plan again and apply.


Errors might occur because resouces were moved from one module to another and terraform might get confused when trying to create a resource that was to be destroyed before, therefore it complains. For example:


```bash
Error: Error applying plan:

2 errors occurred:
        * module.cdis_vpc.module.squid_proxy.aws_iam_role.cluster_logging_cloudwatch: 1 error occurred:
        * aws_iam_role.cluster_logging_cloudwatch: Error creating IAM Role generic-commons_cluster_logging_cloudwatch: EntityAlreadyExists: Role with name generic-commons_cluster_logging_cloudwatch already exists.
        status code: 409, request id: f8b86cfe-dcd2-4423-8be3-ba300ce49b81


        * module.cdis_vpc.module.squid_proxy.aws_route53_record.squid: 1 error occurred:
        * aws_route53_record.squid: [ERR]: Error building changeset: InvalidChangeBatch: [Tried to create resource record set [name='cloud-proxy.internal.io.', type='A'] but it already exists]
        status code: 400, request id: 9a6f2845-403f-4776-b11a-b7c890aaf805
```

At this point it is alright to plan and apply again.

The cluster should still have connectivity, the single squid instance should still be servicing as proxy. The HA ones should also be deployed, but not serving as default gateway and proxying HTTP{,S} traffic yet. 





### 2. Update the EKS module


Start by initializing the module:


```bash
gen3 workon cdistest generic_commons_eks
gen3 cd
```

In order to ensure internet connectivity dure the transition, add the following variables to your `config.tfvars`

```bash
ha_squid   = true
dual_proxy = true
```

We need to also taint a resource for the eks module, for that, run the following:

```bash
gen3 tform taint -module eks aws_route_table.eks_private
```

When that's done, you may proceed as usual

```bash
gen3 tfplan
```

The plan should show the following changes:


Destroy and then create: 

```bash
-/+ destroy and then create replacement
-/+ module.eks.aws_launch_configuration.eks_launch_configuration (new resource required)
-/+ module.eks.aws_route_table.eks_private (tainted) (new resource required)
-/+ module.eks.module.jupyter_pool.aws_launch_configuration.eks_launch_configuration (new resource required)
```

Add:

```bash
  + create
  + module.eks.aws_cloudwatch_event_rule.gw_checks_rule
  + module.eks.aws_cloudwatch_event_target.cw_to_lambda
  + module.eks.aws_cloudwatch_log_group.gwl_group
  + module.eks.aws_iam_role_policy.lambda_policy_no_resources
  + module.eks.aws_iam_role_policy.lambda_policy_resources
  + module.eks.aws_iam_role_policy_attachment.lambda_logs
  + module.eks.aws_lambda_function.gw_checks
  + module.eks.aws_lambda_permission.allow_cloudwatch
  + module.eks.aws_route.for_peering
  + module.eks.aws_route.public_access
  + module.eks.aws_vpc_endpoint.autoscaling
  + module.eks.aws_vpc_endpoint.ebs
  + module.eks.aws_vpc_endpoint.ecr-api
  + module.eks.module.iam_policy.aws_iam_policy.policy
  + module.eks.module.iam_role.aws_iam_role.the_role
```


Modify:

```bash
  ~ update in-place
  ~ module.eks.aws_autoscaling_group.eks_autoscaling_group
  ~ module.eks.aws_eks_cluster.eks_cluster
  ~ module.eks.aws_iam_role.eks_node_role
  ~ module.eks.aws_route_table_association.private_kube[0]
  ~ module.eks.aws_route_table_association.private_kube[1]
  ~ module.eks.aws_route_table_association.private_kube[2]
  ~ module.eks.aws_security_group.eks_control_plane_sg
  ~ module.eks.aws_vpc_endpoint.ec2
  ~ module.eks.aws_vpc_endpoint.ecr-dkr
  ~ module.eks.aws_vpc_endpoint.k8s-logs
  ~ module.eks.aws_vpc_endpoint.k8s-s3
  ~ module.eks.module.jupyter_pool.aws_autoscaling_group.eks_autoscaling_group
  ~ module.eks.module.jupyter_pool.aws_security_group.eks_nodes_sg
```



```bash
Plan: 18 to add, 13 to change, 3 to destroy.
```

Apply the plan

```bash
gen3 tfapply
```



### 3. Removing the single proxy instance route


Asumming you come straight from #2. you won't need to initialize the EKS module, but if you must then:

```bash
gen3 workon cdistest generic_commons_eks
gen3 cd
```

Commment out the dual_proxy variable

```bash
#dual_proxy=true
```

Create the plan

```bash
gen3 tfplan
```

The following resources will change:

Destroy:

```bash
  - destroy
  - module.eks.aws_route.public_access
```


This plan would remove the default route for the subnets associated with kubernetes workers, therefore workers might lose internet connection until the lambda function sees the issue and make tthe respective changes to remediate this and use any of the HA instances.


```bash
gen3 tfapply
```


You could track connectivity status by running something like the following command from devterm 

```bash
for i in {1..500}; do curl -L -s -o /dev/null -w "%{http_code}" http://ifconfig.io --connect-timeout 1; echo; sleep 5; done
```

In this particular case it took about 4 iterations (or 20 seconds) to flip over HA. It should not take longer than one minute, if it does you could revert back by uncommenting `dual_proxy=true` in your config.tfvars




```bash
ubuntu@awshelper-devterm-1581045795:~$ for i in {1..500}; do curl -L -s -o /dev/null -w "%{http_code}" http://ifconfig.io --connect-timeout 1; echo; sleep 5; done
200
200
000
000
000
000
200
200
```



### 4. Remove the squid single instance


Initialize the module 


```bash
gen3 workon cdistest generic_commons
gen3 cd
```

Add the following line to your `config.tfvars` file:

```bash
deploy_single_proxy = false
```

Create the plan

```bash
gen3 tfplan
```

The following changes should be shown:

```bash
  - destroy
  - module.cdis_vpc.aws_security_group.proxy
  - module.cdis_vpc.module.squid_proxy.aws_ami_copy.squid_ami
  - module.cdis_vpc.module.squid_proxy.aws_eip.squid
  - module.cdis_vpc.module.squid_proxy.aws_eip_association.squid_eip
  - module.cdis_vpc.module.squid_proxy.aws_iam_instance_profile.cluster_logging_cloudwatch
  - module.cdis_vpc.module.squid_proxy.aws_iam_role.cluster_logging_cloudwatch
  - module.cdis_vpc.module.squid_proxy.aws_iam_role_policy.cluster_logging_cloudwatch
  - module.cdis_vpc.module.squid_proxy.aws_instance.proxy
  - module.cdis_vpc.module.squid_proxy.aws_route53_record.squid
  - module.cdis_vpc.module.squid_proxy.aws_security_group.login-ssh
  - module.cdis_vpc.module.squid_proxy.aws_security_group.out
  - module.cdis_vpc.module.squid_proxy.aws_security_group.proxy
```


```bash
Plan: 0 to add, 0 to change, 12 to destroy.
```

If the plan looks like above then go ahead and apply, if otherwise, check that nothing is to be destroyed that is not supposed to.

```bash
gen3 tfapply
```



## Considerations

During the migration, internet connectivity from the kubernetes worker nodes might suffer a hiccup, especially if you do not want to deploy a dual proxy option. Even in that case, it should not last longer a few minutes. 

If it goes for longer, you may want to revert.

There might not be any full roll back procedure after you are done.


The lambda function can be invoked through awscli for testing purposes or to force a run when necessary:

```bash
aws lambda invoke --function-name ${vpc_name}-gw-checks-lambda --invocation-type RequestResponse --payload '{"url":"http://ifconfig.io"}' outfile
```


## Extras 

Please refear to [squid-auto](https://github.com/uc-cdis/cloud-automation/tree/master/flavors/squid_auto) for scripts to bootstrap squid instances. Currently there are two options, either running squid directly on the instance as systemd, or on a container.

Deploying directly on the instance might be a bit easier to maintain (if that's required) and troubleshooting, but squid is downloaded from source, compiled and then run, which could take up to 15 mins, depending on the instance type chosen. The smaler the slower. 

Deploying as a container would download our squid image from quay and start the service right away. It might take up to 3 mins to fully complete the bootstraping and start the service. Check the docker file used for the inmage here [Dockerfile](https://github.com/uc-cdis/cloud-automation/tree/master/Docker/squid/Dockerfile).
