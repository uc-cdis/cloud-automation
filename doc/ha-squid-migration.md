# TL;DR

This procedure is intended to show the necessary steps to migrate from a single Squid proxy instance, to an HA/Multizone one.


## Overview

Currently, commons are using a single squid proxy to access the internet. Even though it works just file in most cases, sometimes it might fail, or the underlaying Hardware fails and AWS set it for decomision, or the drive gets full all the sudden which is undesirable. Furthermore, the AMI used as image base was created with Packer and tailored for the needs by that time.

The new HA model will now use official Canonical Ubuntu's 18.04 image and can be easily told to check for the latest release by them.

Moreover, we are placing all instances in an Auto-Scaling group, meaning that if one goes away, it'll be easily replasable, and require little to none supervision.


## Procedure

### 1. Update the VPC module

Start by working on the module:

```bash
gen3 workon cdistest generic-commons
gen3 cd
```

After accessing the module configuration folder, we need to terraform taint a particular resorce othewise, things might fail later. 

The route for the default gateway is now dynamic and will be handled by the squid instances, depending on which becomes the active one.


```bash
gen3 tform taint aws_route_table.private_kube
```

When the resource is tainted, you may proceed as you would regularly do. The plan that will becreated may want to delete a few resources, that's alright, it is inteded. The proxy and a few other will go away for this module

```gen3
gen3 tfplan
```

The plan should look like:

```bash
Terraform will perform the following actions:

  + aws_route.for_peering
      id:                                   <computed>
      destination_cidr_block:               "172.25.64.0/24"
      destination_prefix_list_id:           <computed>
      egress_only_gateway_id:               <computed>
      gateway_id:                           <computed>
      instance_id:                          <computed>
      instance_owner_id:                    <computed>
      nat_gateway_id:                       <computed>
      network_interface_id:                 <computed>
      origin:                               <computed>
      route_table_id:                       "${aws_route_table.private_kube.id}"
      state:                                <computed>
      vpc_peering_connection_id:            "pcx-07cb885401660d19a"

  + aws_route.to_aws
      id:                                   <computed>
      destination_cidr_block:               "54.224.0.0/12"
      destination_prefix_list_id:           <computed>
      egress_only_gateway_id:               <computed>
      gateway_id:                           <computed>
      instance_id:                          <computed>
      instance_owner_id:                    <computed>
      nat_gateway_id:                       "nat-06b494d1f42f1f2fb"
      network_interface_id:                 <computed>
      origin:                               <computed>
      route_table_id:                       "${aws_route_table.private_kube.id}"
      state:                                <computed>

-/+ aws_route_table.private_kube (tainted) (new resource required)
      id:                                   "rtb-0eef28cd989935468" => <computed> (forces new resource)
      owner_id:                             "707767160287" => <computed>
      propagating_vgws.#:                   "0" => <computed>
      route.#:                              "3" => <computed>
      tags.%:                               "3" => "3"
      tags.Environment:                     "generic-commons" => "generic-commons"
      tags.Name:                            "private_kube" => "private_kube"
      tags.Organization:                    "Basic Service" => "Basic Service"
      vpc_id:                               "vpc-0a23ca51a42b14464" => "vpc-0a23ca51a42b14464"

  ~ aws_route_table_association.private_kube
      route_table_id:                       "rtb-0eef28cd989935468" => "${aws_route_table.private_kube.id}"

  - aws_security_group.kube-worker

  - aws_vpc_endpoint.k8s-s3

  - module.cdis_vpc.aws_ami_copy.login_ami

  - module.cdis_vpc.aws_iam_instance_profile.cluster_logging_cloudwatch

  - module.cdis_vpc.aws_iam_role.cluster_logging_cloudwatch

  - module.cdis_vpc.aws_iam_role_policy.cluster_logging_cloudwatch

  - module.cdis_vpc.aws_route53_record.squid

  ~ module.cdis_vpc.aws_security_group.local
      egress.3234615024.cidr_blocks.#:      "0" => "1"
      egress.3234615024.cidr_blocks.0:      "" => "192.168.144.0/20"
      egress.3234615024.description:        "" => ""
      egress.3234615024.from_port:          "" => "0"
      egress.3234615024.ipv6_cidr_blocks.#: "0" => "0"
      egress.3234615024.prefix_list_ids.#:  "0" => "0"
      egress.3234615024.protocol:           "" => "-1"
      egress.3234615024.security_groups.#:  "0" => "0"
      egress.3234615024.self:               "" => "false"
      egress.3234615024.to_port:            "" => "0"
      egress.3505169447.cidr_blocks.#:      "2" => "0"
      egress.3505169447.cidr_blocks.0:      "192.168.144.0/20" => ""
      egress.3505169447.cidr_blocks.1:      "54.224.0.0/12" => ""
      egress.3505169447.description:        "" => ""
      egress.3505169447.from_port:          "0" => "0"
      egress.3505169447.ipv6_cidr_blocks.#: "0" => "0"
      egress.3505169447.prefix_list_ids.#:  "0" => "0"
      egress.3505169447.protocol:           "-1" => ""
      egress.3505169447.security_groups.#:  "0" => "0"
      egress.3505169447.self:               "false" => "false"
      egress.3505169447.to_port:            "0" => "0"
      tags.%:                               "2" => "3"
      tags.Name:                            "" => "generic-commons-local-sec-group"

  ~ module.cdis_vpc.aws_security_group.out
      tags.%:                               "2" => "3"
      tags.Name:                            "" => "generic-commons-outbound-traffic"

  - module.cdis_vpc.aws_security_group.proxy

  - module.cdis_vpc.aws_security_group.webservice

  - module.cdis_vpc.module.squid_proxy.aws_ami_copy.squid_ami

  - module.cdis_vpc.module.squid_proxy.aws_eip.squid

  - module.cdis_vpc.module.squid_proxy.aws_eip_association.squid_eip

  - module.cdis_vpc.module.squid_proxy.aws_instance.proxy

  - module.cdis_vpc.module.squid_proxy.aws_security_group.login-ssh

  - module.cdis_vpc.module.squid_proxy.aws_security_group.out

  - module.cdis_vpc.module.squid_proxy.aws_security_group.proxy


Plan: 3 to add, 3 to change, 17 to destroy.
```


If it doesn't look like above, make sure the no harm will be done to production clusters. Then apply the plan.


```bash
gen3 tfapply
```


### 2. Update the EKS module


Start by initializing the module:

```bash
gen3 workon cdistest generic_commons_eks
gen3 cd
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
Plan: 22 to add, 8 to change, 1 to destroy.
```

Apply the plan

```bash
gen3 tfapply
```



## Considerations

During the migration, when you first update the VPC module, the proxy will go away, leaving you temporarily without a connection to the internet from the worker nodes, you may want to plan accordingly. Nonetheless, services will be available to users, but if you use an internal authentication provider, like google, dbGap, among others, these ones may not work until there is an available proxy.

After you update the EKS module the Squid instances may take a few minutes to fully start serving proxy services, Say it might take up to 20 minutes.

There might not be any roll back procedure after you are done.
