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

### gen3 workon aws-profile-name vpc-name

```
ex:$ gen3 workon cdistest plaxplanetv1
```

Enter (and initialize if necessary) a local workspace for working with the VPC with the given VPC under the AWS account accessible with admin credentials
under the *aws-profile-name* profile in `~/.aws/credentials`.
This is a prerequisite for most other gen3 commands.

The gen3 tools stores commons related data (including secrets)locally under *$XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_VPC_NAME* -
conforming with the linux [xdg desktop specification](https://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html).

The tasks performed include:

* set the $GEN3_AWS_PROFILE and $GEN3_VPC_NAME environment variables
* if a local $XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_VPC_NAME exist, then
  - pull down any missing state from s3
  - run terraform init if necessary
* else if GEN3_VPC_NAME state exists in S3, then
  - copy the state from S3
  - generate terraform secrets based on the AWS profile credentials
  - run terraform init
* else
   - setup template config files
       * assumes ~/.ssh/id_rsa.pub
          is the user a good key to access the bastion host
* fi
* setup the *cdis-terraform-state.profile-name.gen3* S3 bucket if necessary
* run `terraform init` if necessary
   
### gen3 status

List the variables associated with the current gen3 workspace - ex:

```
$ gen3 status
GEN3_PROFILE=cdistest
GEN3_VPC=planxplanetv1
GEN3_WORKDIR=/home/reuben/.local/share/gen3/cdistest/planxplanetv1
GEN3_HOME=/home/reuben/Code/PlanX/cloud-automation
GEN3_S3_BUCKET=cdis-terraform-state.cdistest.gen3
AWS_PROFILE=cdistest
```

### gen3 ls

List workspaces that have been worked on locally - ex:

```
$ gen3 ls
local workspaces under /home/reuben/.local/share/gen3
cdistest    gen3test
cdistest    planxplanetv1
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

### gen3 kube-up

Not yet implemented 

### gen3 dict-update

Not yet implemented 

### gen3 kube-deploy deployment-name

Not yet implemented 

## Migrating existing AWS commons to gen3

The gen3 tools expect the terraform variable files (config.tfvars and backend.tfvars)
to exist under
```
    s3://${GEN3_S3_BUCKET}/${GEN3_VPC}/
```
Those variable files do not include aws credentials - gen3 will harvest those
from your local aws profile to another set of local aws_*.tfvars files that are not 
backed up to S3.

Here is one strategy for migration:
* `gen3 workon profile-name vpc-name`

This will create a local workspace with config.tfvars and backend.tfvars
files generated from a template that auto-generates new passwords, etc.
It will also auto-create the GEN3_S3_BUCKET (defaults to cdis-terraform-state.profile-name.gen3)
S3 bucket if it does not yet exist.

* `gen3 cd`

This will cd your shell into the workspace folder.

* Update config.tfvars and backend.tfvars with appropriate values
* `gen3 tfplan`
* `gen3 tfapply`

Only tfapply if the plan is not destructive.
The tfapply will automatically backup the local config.tfvars, backend.tfvars, and README.md to S3.

* Optionally - update backend.tfvars, so that terraform stores its S3 state in the same folder as config.tfvars, then run `terraform init` to move the state, and gen3 tfplan; gen3 tfapply; to sync everything up with s3 - ex:
```
$ cat backend.tfvars 
bucket = "cdis-terraform-state.cdistest.gen3"
encrypt = "true"
key = "gen3test"
region = "us-east-1"

#
# gen3 workon ... will run 'terraform init' - which will in turn prompt you to migrate the 
# if it has changed 
#

$ gen3 workon cdistest gen3test
$ gen3 tfplan
# Note: tfplan should propose no resource changes.
#   Still run tfapply to sync up the state in S3.
$ gen3 tfapply
```

## VPC naming conventions

The *gen3* tools follow these VPC naming conventions to determine which terraform stack to build in the VPC.
* a VPC name that ends in '_user' is a user VPC (for user VM's) on AWS defined by the resources in `cloud-automation/tf_files/aws_user_vpc`
* every other VPC name is a commons VPC on AWS defined by resources in `cloud-automation/tf_files/aws`
