# TL;DR

The gen3 [cloud-automation](../README.md) bash scripts simplify and standardize common devops tasks on a gen3 commons.

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

More examples and use cases can be found on the [gen3 help](../doc/README.md) docs

### gen3 workon aws-profile-name workspace-name

```
ex:$ gen3 workon cdistest plaxplanetv1
```

Enter (and initialize if necessary) a local workspace for working with the terraform resources under the AWS account
accessible using the admin credentials
under the *aws-profile-name* profile in `~/.aws/credentials`.
See [tf_files/README.md](../tf_files/README.md) for more details.


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


### gen3 g3k_testsuite

Test suite with mocks that work for local unit testing.

### gen3 testsuite

Test suite assumes AWS and terraform access.

### devterm
Open a bash shell on the cluster in an `awshelper` container: `gen3 devterm`

The `devterm` command can also pass a command to the bash shell (`bash -c`) - ex:
`gen3 devterm "nslookup fence-service"`

