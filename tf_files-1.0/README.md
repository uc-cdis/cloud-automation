# TL;DR

Terraform rules for bringing up cloud resources in different stacks.  Use the [gen3](../gen3/README.md) helper scripts to simplify running terraform and other devops tasks.

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

The [gen3 helper scripts](../gen3/README.md) standardize and simplify this process.

## tf_files/aws/commons

Resources for a gen3 commons in an AWS VPC.
```
gen3 workon cdistest devplanetv1
```

### VPC peering request acceptance by CSOC admin VM
When we launch a new data commons; it fails when we run the `gen3 tfapply` for the first time. At this point, we need to login to the csoc_admin VM and run the following command:
gen3 approve_vpcpeering_request <child_vpc_name>
The underneath script basically looks for a new VPC peering request, if any accepts it, tags it and create an appropriate route to the csoc_main_vpc private subnet route table. This script accepts an optional flag `--get-route-table` which programmatically gets the route table id(s) of the VPC which is accepting the peering request.


Once this is completed successfully, we can run the `gen3 tfplan` and `gen3 tfapply` again.

## tf_files/aws/data_bucket

Create a data bucket and associated IAM roles, policies, and profiles.
```
gen3 workon gen3 vpcname_projname_databucket
```

## tf_files/aws/rds_snapshot

Terraform resources tracking snapshots of the RDS resources in a commons.
```
gen3 workon devplanetv1_snapshot
```

## tf_files/aws/user_vpc

Resources for a user VPC in AWS - which provides a network for creating user VM's
```
$ gen3 workon gen3 commons_user
```

## tf_files/aws/csoc_admin_vm

Setup the *admin vm* in the CSOC account for a particular child account.
```
$ gen3 workon csoc cdistest_adminvm
```

## tf_files/aws/utility_vm

Setup and utilityVM that would follow a bootstrap scrip.
```
$ gen3 workon <profile> <commons_name>_es
```

## tf_files/aws/commons_vpc_es

Setup an ElasticSearch cluster for arranger to access it.
```
$ gen3 workon <profile> <commons name>_es
```

## tf_files/aws/modules

Terraform code shared as modules.

## gen3 tools: workon, tfplan, tfapply, ...

The gen3 tools store commons related data (including secrets) locally under *$XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_WORKSPACE_NAME* -

#### workspace types

The type of workspace setup depends upon the workspace name.  The following
types of workspace are supported:

* *admin vm*

The *admin vm* type workspace is intended to create an EC2 instance in the *CSOC* account to act as the CSOC's admin workstation for another account with VPC's that are peered with the CSOC.  If the workspace name ends in `_adminvm`, then the `gen3` script configures
an *admin vm* workspace - ex:
```
$ gen3 workon csoc cdistest_adminvm
```

An *admin vm* workspace creates an EC2 instance in the CSOC that is associated with a child account.  The EC2 instance is linked with a CSOC IAM role that can assume admin privileges in the child account.  A security group allows the VM to communicate with VPC's in the child account, and prevents communication with VPC's from other accounts also peered with the CSOC.

* *logging*

The *logging* type workspace is intended as a destination for logs that will be produced by the actual commons cluster. This module should be ran prior running any commons, otherwise it may conflict when the commons tries to attach the logging group of the common to the CSOC account destinations.

```
$ gen3 workon csoc common_logging
```

This module will create a Kinesis stream service, a lambda function, and a couple of firehoses. The latest one would be in charge of sending whatever the commons account forwards into an ElasticSearch domain along with a S3 bucket that will also be created with the name of the common.

* *commons*

Any workspace that does not match one of the other types is considered a *commons* type workspace - ex:
```
$ gen3 workon cdistest devplanetv1
```

A *commons* workspace extends the *user vpc* type workspace with additional subnets to host a kubernetes cluster.


* *databucket*

If the workspace name ends in `_databucket`, then the `gen3` script configures
a *databucket* type workspace - ex:
```
$ gen3 workon cdistest devplanetv1_proj1_databucket
```

A *databucket* workspace creates an encrypted S3 data bucket,
another S3 bucket to store the access logs from the data bucket,
a read-only role and instance-profile, and a read-write role and instance-profile.

* *user vpc*

If the workspace name ends in `_user`, then the `gen3` script configures
a *user vpc* type workspace - ex:
```
$ gen3 workon cdistest devplanetv1_proj1_user
```

A *user vpc* workspace created a VPC with a bastion, squid proxy, public and private subnets that route egress traffic through the proxy, cloudwatch logs, and VPC peering to the CSOC VPC.

* *rds snapshot*

If the workspace name ends in `_snapshot`, then the `gen3` script configures
a workspace that simply collects snapshots of the specified RDS databases - ex:
```
$ gen3 workon cdistest devplanetv1_snapshot
```


#### workspace details

The gen3 tools stores workspace data (including secrets) locally under *$XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_WORKSPACE_NAME* -
conforming with the linux [xdg desktop specification](https://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html).

The tasks performed include:

* set the $GEN3_AWS_PROFILE and $GEN3_WORKSPACE environment variables
* if a local $XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_WORKSPACE exist, then
  - pull down any missing state from s3
  - run terraform init if necessary
* else if GEN3_WORKSPACE_NAME state exists in S3, then
  - copy the state from S3
  - generate terraform secrets based on the AWS profile credentials
  - run terraform init
* else
   - setup template config files
       * assumes ~/.ssh/id_rsa.pub
          is the user a good key to access the bastion host
* fi
* setup the *cdis-state-ac{ACCOUNTID}-gen3* S3 bucket if necessary
* run `terraform init` if necessary
