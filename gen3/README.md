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

## gen3 cli

gen3 [flags] command [command options]

### global flags

gen3 [flags] command

* --dryrun
* --verbose

Ex:

*  
```
gen3 workon accountname vpcname
gen3 --dryrun refresh
```

### gen3 workon aws-profile-name vpc-name

```
ex:$ gen3 workon cdis-test plaxplanetv1
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
* setup the *cdis-terraform-state* S3 bucket if necessary
* run `terraform init` if necessary
   

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

### gen3 kube-up

Not yet implemented 

### gen3 dict-update

Not yet implemented 

### gen3 kube-deploy deployment-name

Not yet implemented 

### gen3 ssh nodename

Not yet implemented 

## gen3 development

Not yet implemented 

### Test suite

Not yet implemented 

### Dry run 

Not yet implemented 
