# TL;DR

The gen3 cloud-automation bash scripts simplify and standardize common devops tasks on a gen3 commons.

## installation 

Install the gen3 scripts on a system like this:

* Install prerequisites, so that they are in the bash environment's runtime PATH
  - [awscli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
  - [terraform](https://www.terraform.io/downloads.html)
  - [jq](https://stedolan.github.io/jq/)

* git clone https://github.com/uc-cdis/cloud-automation.git
* add the following block to your ~/.bashrc script

```
export GEN3_HOME=~/"Path/To/cloud-automation"
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi

```

* open a new shell
* setup AWS profiles for each account that you interact with in ~/.aws/credentials and ~/.aws/config -
    [https://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html)


## gen3 cli

gen3 [flags] command [command options]

### global flags

gen3 [flags] command

* --dryrun
* --verbose

```
ex:$ gen3 workon accountname vpcname
ex:$ gen3 --dryrun refresh
```

### gen3 help

Show this README.
You can also run `gen3 COMMAND help` for most commands:

```
ex: $ gen3 tfapply help
  gen3 tfapply:
    Run 'terraform apply' in the current workspace, and backup config.tfvars, backend.tfvars, and README.md.  
    A typical command line is:
       terraform apply plan.terraform

```

### gen3 workon aws-profile-name workspace-name

```
ex:$ gen3 workon cdistest plaxplanetv1
```

Enter (and initialize if necessary) a local workspace for working with the workspace resources under the AWS account accessible with admin credentials
under the *aws-profile-name* profile in `~/.aws/credentials`.
This is a prerequisite for most other gen3 commands.

The gen3 tools store commons related data (including secrets) locally under *$XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_WORKSPACE_NAME* -

#### workspace types

The type of workspace setup depends upon the workspace name.  The following
types of workspace are supported:

* *admin vm*

The *admin vm* type workspace is intended to create an EC2 instance in the *CSOC* account to act as the CSOC's 
admin workstation for another account with VPC's that are peered with the CSOC.  If the workspace name ends in `_adminvm`, then the `gen3` script configures
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

A *commons* workspace extends the *user vpc* type workspace with additional subnets to host a kubernetes cluster, and adds a `kubernetes provisioner` EC2 instance.  

Note: we plan to deprecate both the `k8s provisioner` and the `bastion node` in *commons* VPC's in favor of accessing a commons through its *admin vm* in the *CSOC* account - which is accessed via VPN.


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

### gen3 arun command arg1 arg2 ...
   
Generalization of `gen3 aws ...` just below, 
so  `gen3 arun aws arg1 arg2 ...` is equivalent to
`gen3 aws arg1 arg2 ...`
 
### gen3 aws arg1 arg2 ...

Run the `aws` command with the given arguments after setting the
environment to conform to the active workspace's `~/.aws/config` profile -
acquiring temporary credentials as necessary.  

For example - `gen3 workon cdistest devplanetv1` with the following 
configuration prompts the user for an MFA token, acquire a token
for the `role_arn` specified by the `cdistest` profile, and cache the
token (and auto renew when it expires):

```
[profile cdistest]
output = json
region = us-east-1
role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
role_session_name = gen3-reuben
source_profile = csoc
mfa_serial = arn:aws:iam::433568766270:mfa/reuben-csoc

[profile csoc]
mfa_serial = arn:aws:iam::433568766270:mfa/reuben-csoc
# AWS_PROFILE=csoc aws sts get-session-token --serial-number arn:aws:iam::433568766270:mfa/reuben-csoc --token-code XXXX
```

Similarly, `gen3 workon csoc cdistest_adminvm` with the above profile
prompts the user for an MFA token, then acquire and cache credentials.

Finally, `gen3 workon cdistest devplanetv1` with the following configuration
also acquires a token for the specified role, but uses credentials
from the EC2 metadata service to assume the role rather than
look for `csoc` credentials in `~/.aws/credentials`.

```
[profile cdistest]
output = json
region = us-east-1
role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
role_session_name = gen3-reuben
credential_source = Ec2InsanceMetadata
```


### gen3 status

List the variables associated with the current gen3 workspace - ex:

```
$ gen3 status
GEN3_PROFILE=cdistest
GEN3_WORKSPACE=planxplanetv1
GEN3_WORKDIR=/home/reuben/.local/share/gen3/cdistest/planxplanetv1
GEN3_HOME=/home/reuben/Code/PlanX/cloud-automation
GEN3_S3_BUCKET=cdis-state-ac23212121-gen3
AWS_PROFILE=cdistest
```

### gen3 ls [PROFILE]

List workspaces that have been worked on locally, and 
workspaces saved to S3 if for a given PROFILE - ex:

```
$ gen3 ls
local workspaces under /home/reuben/.local/share/gen3
cdistest    gen3test
cdistest    planxplanetv1

$ gen3 ls cdistest
cdistest profile workspaces under s3://cdis-state-ac707767160287-gen3
                           PRE devplanetv1/
                           PRE gen3test_databucket/
                           PRE qaplanetv1/
                           PRE raryav1/
                           PRE reuben_databucket/
                           PRE vpcoctettest/

cdistest profile workspaces under legacy path s3://cdis-terraform-state.account-707767160287.gen3
                           PRE fauziv1/
                           PRE planxplanet_user/

local workspaces under /home/reuben/.local/share/gen3
cdistest    devplanetv1
```

### gen3 refresh

```
ex:$ gen3 refresh
```

Backup the local .tfvars files in the current workspace, and replace them with copies from s3 if available.
You'll usually want to refresh your workspace when you return to it after some time away.

### gen3 cd [home|workspace]

```
ex:$ gen3 cd workspace
ex:$ gen3 cd home
ex:$ gen3 cd  # defaults to workspace
```

This is just a little shortcut to 'cd' the shell to $GEN3_HOME
or $GEN3_WORKDIR

Note: defaults to *workspace* if not *home*

### gen3 tfplan

```
gen3 tfplan
```

Just a little wrapper around 'terraform plan' that passes the required flags, and
bails out if the generated plan deletes AWS resources unless -f is given.


### gen3 tfapply

Apply the last plan from `gen3 tfplan`, and perform supporting tasks:

* backup tf config variable files to S3
* auto-generate entries for ~/.ssh/config if not already present
* rsync the terraform generated _output/ scripts to the k8s provisioner

### gen3 tfoutput

A wrapper around [terraform output](https://www.terraform.io/intro/getting-started/outputs.html).  Ex:

```
$ gen3 tfoutput ssh_config
Host login.planxplanetv1
   ServerAliveInterval 120
   HostName XX.XXX.XXX.XXX
   User ubuntu
   ForwardAgent yes

Host k8s.planxplanetv1
   ServerAliveInterval 120
   HostName 172.XX.XX.XX
   User ubuntu
   ForwardAgent yes
   ProxyCommand ssh ubuntu@login.planxplanetv1 nc %h %p 2> /dev/null

```

### gen3 testsuite

Run the test suite.  Requires a 'cdistest' profile.

### g3k 

The `g3k` tools are now also available via `gen3`,
so `gen3 roll sheepdog` is equivalent to `g3k roll sheepdog`.

```
$ g3k help
  
  Use:
  g3k COMMAND - where COMMAND is one of:
    backup - backup home directory to vpc's S3 bucket
    devterm - open a terminal session in a dev pod
    help
    jobpods JOBNAME - list pods associated with given job
    joblogs JOBNAME - get logs from first result of jobpods
    pod PATTERN - grep for the first pod name matching PATTERN
    pods PATTERN - grep for all pod names matching PATTERN
    psql SERVICE 
       - where SERVICE is one of sheepdog, indexd, fence
    replicas DEPLOYMENT-NAME REPLICA-COUNT
    roll DEPLOYMENT-NAME
      Apply the current manifest to the specified deployment - triggers
      and update in most deployments (referencing GEN3_DATE_LABEL) even 
      if the version does not change.
    runjob JOBNAME 
     - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
    testsuite
    update_config CONFIGMAP-NAME YAML-FILE
```

There are some helper functions in [kubes.sh](https://github.com/uc-cdis/cloud-automation/blob/master/kube/kubes.sh) for k8s related operations.

### roll
`g3k roll $DEPLOYMENT_NAME` updates the deployed pods to the 
docker image currently referenced by `cdis-manifest` - 
forces the pod to update even if the image tag has not changed

ex: `g3k roll fence`

Also, `g3k roll all` rolls all services in order, and creates missing
secrets and configuration if the `~/${vpc_name}_output/creds.json` and
similar files are present.

### get_pod
`g3k get_pod $DEPLOYMENT_SUBSTRING` get one of the pods' name for a deployment, this is handy when you want to just run a command on one pod, eg:
`kubectl exec $(get_pod gdcapi) -c gdcapi ls`.

### update_config
`g3k update_config $CONFIG_NAME $CONFIG_FILE` this will delete old configmap and create new configmap with updated content

### run_job

```
ubuntu@ip-172-16-36-26:~$ g3k update_config fence planxplanetv1/apis_configs/user.yaml 
configmap "fence" deleted
configmap "fence" created

ubuntu@ip-172-16-36-26:~$ g3k runjob useryaml
job "useryaml" deleted
job "useryaml" created
```

### g3k_help

```
ubuntu@ip-172-16-36-26:~$ g3k help
  
  Use:
  g3k COMMAND - where COMMAND is one of:
    help
    jobpods JOBNAME - list pods associated with given job
    joblogs JOBNAME - get logs from first result of jobpods
    pod PATTERN - grep for the first pod name matching PATTERN
    pods PATTERN - grep for all pod names matching PATTERN
    replicas DEPLOYMENT-NAME REPLICA-COUNT
    roll DEPLOYMENT-NAME
      Apply a superfulous metadata change to a deployment to trigger
      the deployment's running pods to update
    runjob JOBNAME K1 V1 K2 V2 ...
     - JOBNAME also maps to cloud-automation/kube/services/JOBNAME-job.yaml
    update_config CONFIGMAP-NAME YAML-FILE
```



## VPC naming conventions

The *gen3* tools follow these VPC naming conventions to determine which terraform stack to build in the VPC.
* a VPC name that ends in '_user' is a user VPC (for user VM's) on AWS defined by the resources in `cloud-automation/tf_files/aws/user_vpc`
* every other VPC name is a commons VPC on AWS defined by resources in `cloud-automation/tf_files/aws/commons`


## VPC peering request acceptance by CSOC admin VM
When we launch a new data commons; it fails when we run the `gen3 tfapply` for the first time. At this point, we need to login to the csoc_admin VM and run the following command:
gen3 approve_vpcpeering_request <child_vpc_name>
The underneath script basically looks for a new VPC peering request, if any accepts it, tags it and create an appropriate route to the csoc_main_vpc private subnet route table.
Once this is completed successfully, we can run the `gen3 tfplan` and `gen3 tfapply` again.
