# TL;DR

This procedure is intended to show the necessary steps required to migrate from a single Squid proxy instance, to an HA/Multizone one.


## Overview

Currently, commons are using a single squid proxy to access the internet. Even though it works just file in most cases, sometimes it fails, or the underlaying hardware fails and consequently AWS sets it for decomision, or the instance volume fills up all the sudden, among others. Furthermore, the AMI used as image base was created with Packer and tailored for the needs by that time.

The new HA model will now use official Canonical Ubuntu's 18.04 image and can be easily told to check for the latest release by them. This leaves the burden to keep the instance updated and check on it.

Logs are sent over to cloudwatch for historical data. Therefore, instances are disposable. 

Keeping at least two instances always up, one as active and the second as standby, would decrease the amount of time commons are left out of internet access. The standby instance would come in place if the active one fails for whatever reason, there'll be a lambda function checking for http access from within the very same VPC where the commons lives and port 3128 on each individual instance. Should those two succeed, then the proxy is switched to the stand by.

The switching happens at the network level, the default route for kubernetes workers is an instance ENI in the autoscaling group that manages the squid cluster. If http access fails, then each instance in squid autoscaling group is checked on port 3128, the first one that works is set as the new active.

This new module, or addition, has been though to be optional. You can decide to keep the single instance model or switch to HA. If you don't want to incurd in additional charged that represents keeping an standby EC2 instance, then you can always set the cluster min and desired size of 1.


## Procedure

The procedure has been broken down to two options. One would deploy HA-squid on top of the single instance, meaning they'll run simultaenously. The second, would just destroy the single instance one and deploy HA alone.

The first option would mean little to no downltime, but would require more resources deployed at some point in time, which might mean of higher bills.

The second option is instended for non critical environments as it might leave the kubernetes worker nodes without internet access while the HA squid instances come up. Which could take up to 30 mins, depending on the case and the instance type selected.

It worth noting than for the first option you could destroy the single instance model once you know HQ is in place. The best way to determine if it is, is to check on the default gateway for the route table for `private_kube` and `eks_private`, both should be pointing to an ENI belonging to an instance in the HA squid cluster.

The following steps would show what needs to be done in order to deploy HA-squid in your commons.


### 1. Update the VPC module

Note: All these steps showed here were done on a deployment that runed on the latest master prior ha squid was introduced, the amount of resources terraform would need to add/modify/destroy might differ for each environment. Proceed with precausion.

      Also, this guide will go through a parallel deployent of squid instance, and then removal of the single instance. This way, the amount of time the a cluster won't have internet access gets reduced to maximun a minute, which is the frequency lambda runs and checks.


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

When the resource is tainted, you may proceed as you would regularly do. The plan to be created may want to delete a few resources, that's alright, it is inteded.

Tell terraform you want to deploy HA squid in config.tfvars 

```
deploy_ha_proxy = true
```


```gen3
gen3 tfplan
```

The plan should look show the following: 

Tainted resources:

-/+ destroy and then create replacement
-/+ aws_route_table.private_kube (tainted) (new resource required)


Add:

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


Modify:

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


Destroy:

  - destroy
  - aws_security_group.kube-worker
  - aws_vpc_endpoint.k8s-s3
  - module.cdis_vpc.aws_ami_copy.login_ami
  - module.cdis_vpc.aws_iam_instance_profile.cluster_logging_cloudwatch
  - module.cdis_vpc.aws_iam_role.cluster_logging_cloudwatch
  - module.cdis_vpc.aws_iam_role_policy.cluster_logging_cloudwatch
  - module.cdis_vpc.aws_route53_record.squid
  - module.cdis_vpc.aws_security_group.webservice





Terraform will perform the following actions:

```bash
Plan: 19 to add, 10 to change, 9 to destroy.
```

If it doesn't look like above, make sure the no harm will be done to production clusters. Then apply the plan.


```bash
gen3 tfapply
```

Sometimes terraform might fail applying a plan due to different reasouns, you can run the plan again and apply.


Errors might occur because resouces were moved from one module to another and terraform might confuse when they are still deployed or not, therefore it complains. For example:

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

The cluster should still have connectivity at this point, the single squid instance should still be servicing as proxy. The HA ones should also be deployed, but not serving as default gateway and proxying HTTP{,S} traffic yet. 


### 2. Update the EKS module


Start by initializing the module:


```bash
gen3 workon cdistest generic_commons_eks
gen3 cd
```

In order to ensure internet connectivity dure the transition, add the following variables to your `config.tfvars`

```bash
ha_proxy   = true
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

The plan for the EKS module should not delete any resource other than the one you just tainted. If otherwise, please check the plan thoroughly.


```bash
Plan: 27 to add, 8 to change, 1 to destroy.
```

Apply the plan

```bash
gen3 tfapply
```



## Considerations

During the migration, when you first update the VPC module, the proxy will go away, leaving you temporarily without a connection to the internet from the worker nodes, you may want to plan accordingly. Nonetheless, services will be available to users, but if you use an internal authentication provider, like google, dbGap, among others, these ones may not work until there is an available proxy.

After you update the EKS module the Squid instances may take a few minutes to fully start serving proxy services, Say it might take up to 20 minutes.

There might not be any roll back procedure after you are done.


aws lambda invoke --function-name S3toES2 --invocation-type Event --payload '{"prefix":"09/'$j'/'$i'"}' outfile
