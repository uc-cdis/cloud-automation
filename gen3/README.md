# TL;DR

The gen3 cloud-automation bash scripts simplify and standardize common devops tasks on a gen3 commons.

## installation 

Install the gen3 scripts on a system like this:

* Install prerequisites, so that they are in the bash environment's runtime PATH
  - [awscli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
  - [terraform](https://www.terraform.io/downloads.html)

* git clone https://github.com/uc-cdis/cloud-automation.git
* add the following block to your ~/.bashrc script
```
export GEN3_HOME=~/"Path/To/cloud-automation"
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  export XDG_DATA_HOME=${XDG_DATA_HOME:-~/.local/share}
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi

```

* open a new shell

## Tools

### global flags

gen3 [flags] command

* -f,--force
* -n,--dry-run
* -y,--yes


### gen3 setup aws-profile-name

Initialize the the AWS account accessible with admin credentials
under the *aws-profile-name* profile in `~/.aws/credentials`
for use with gen3 - including the following tasks:

* create the *cdis-terraform-state* S3 bucket for backing up terraform state and other private VPC configurations (like Jenkins backups)
* create the *cdis-kube-aws* S3 bucket (for *kube-aws* cloud-formation execution)
* create the *cdis-public* S3 bucket for publishing public files like dictionary definitions


### gen3 workon aws-profile-name vpc-name

Initialize a local workspace for working with the VPC with the given VPC under the AWS account accessible with admin credentials
under the *aws-profile-name* profile in `~/.aws/credentials`.

The gen3 tools stores commons related data (including secrets)locally under *$XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_VPC_NAME* -
conforming with the linux [xdg desktop specification](https://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html).

The tasks performed include:
* set the $GEN3_AWS_PROFILE and $GEN3_VPC_NAME environment variables
* if a local $XDG_DATA_HOME/$GEN3_AWS_PROFILE/$GEN3_VPC_NAME exist, then
  - warn if the local tfvars are out of sync with s3
* else if GEN3_VPC_NAME state exists in S3, then
  - copy the state from S3
  - generate terraform secrets based on the AWS profile credentials
  - run terraform init
* else
   - setup template config files
       * assumes ~/.ssh/${GEN3_VPC_NAME}.pub or ~/.ssh/id_rsa.pub
          is the user a good key to access the bastion host
   - run terraform init
   - point the user at instructions for setting up the configuration for the new VPC

### gen3 tfplan

Bail out if the generated plan deletes AWS resources unless -f is given.

### gen3 tfapply

Apply the last plan from `gen3 tfplan`, and perform supporting tasks:

* backup tf config variable files to S3
* auto-generate entries for ~/.ssh/config if not already present
* rsync the terraform generated _output/ scripts to the k8s provisioner

### gen3 kube-up

### gen3 dict-update

### gen3 kube-deploy deployment-name

### gen3 ssh nodename

## gen3 development

### Test suite


### Dry run 

