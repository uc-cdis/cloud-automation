# TL;DR

This code supports automation of several PlanX processes:

* `./tf_files` - terraform infrastructure automation - for creating resources in the cloud 
like databuckets, networks, databases, and kubernetes clusters
* `./kube` - kubernetes automation - for deploying services, configuration, secrets, and jobs
to a kubernetes cluster 
* `./Docker` - image automation - for building various Docker images including *Jenkins* and *devterm*
* `./Jenkins` - Jenkins pipelines - for automating workflows like backing up the Jenkins server, testing the *cloud-automation* repo, and continuously deploying to the *QA* environments
* `./gen3` - user friendly-ish tools to simplify workflows with the `./kube` kubernetes and `./tf_files` terraform automation - [more details](./gen3/README.md)

The repository also interacts closely with the [images](https://github.com/uc-cdis/images)
and [cdis-manifest] 

# Workflows

## AWS CSOC

Most of our interaction with CDIS AWS accounts occur via the central CDIS CSOC account.
[This page](https://github.com/uc-cdis/cdis-wiki/blob/master/ops/CSOC_Documentation.md) describes the CSOC architecture

## New account flow

* Create an `csoc_adminvm` role in the new account with a trust relationship that allows 
the CSOC account to create roles that can assume the `csoc_adminvm` role in the new account:
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::433568766270:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
```

* Create a new `admin-vm` in the CSOC.  An administrator logs into an account's admin-vm to interact with the account's AWS API and kubernetes clusters:
    - connect to the CSOC VPN (requires multifactor authentication)
    - ssh to the adminvm
Contact CDIS ops team to request access to the CSOC VPN, and to add your ssh public key to the
appropriate adminvm.

## New commons flow

The CDIS ops team follows this flow to create a new commons.

* Login to the adminvm
* Create a user account for the commons.  There is one `admin-vm` per AWS account.  We create one `user` on an account's admin-vm for each commons VPC under the account.
Note that an `adminvm` acquires credentials to interact with the AWS API via the EC2 metadata service.  For example, user accounts on the `cdistest` admin-vm have the following configuration:
```
$ cat ~/.aws/config 
[default]
output = json
region = us-east-1
role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
credential_source = Ec2InstanceMetadata

[profile cdistest]
output = json
region = us-east-1
role_arn = arn:aws:iam::707767160287:role/csoc_adminvm
credential_source = Ec2InstanceMetadata
```

* Login to the commons account - ex: `ssh commons@account-admin-vm.csoc`
* Run terraform to bring up a VPC to host the commons:
```
$ gen3 workon account-profile commons-name
$ gen3 cd
$ configure VPC CIDR in `config.tfvars`
$ gen3 tfplan
$ gen3 tfapply
```
* Copy the commons config files to the home directory: `cp {VPC_NAME}_output ~/{VPC_NAME}_output`
* Run `kube-aws` (via the `kube-up` command)
```
cd ~/{VPC_NAME}_output
bash kube-up.sh
```
* Bring up the commons
```
source ~/.bashrc
edit ~/{VPC_NAME}/00configmap.yaml
edit ~/{VPC_NAME}_output/creds.json
gen3 roll all
```

## Prerequisites for Commons


#### Google OAUTH credentials

We register each commons (going forward) as an OAuth client of the `cdis-test` project
under the `planx-pla.net` GCP domain (organization).  Contact the CDIS *ops* 
team to request a Google client-id and secret for a new commons to support *"Login with Google"*.

- [Create a Google project](https://console.developers.google.com/projectcreate?previousPage=%2Fprojectselector%2Fapis%2Fapi%2Fplus.googleapis.com%2Foverview) with the project name you want to use.
- Enable the Google+ API after you create your project, the link above should take you there after project creation.
- Click "Create Credentials" choose the "Google+ API", then choose "Web server" as API from, and choose "User data" as the data being accessed.
- For the "Authorized JavaScript Origins" enter just the hostname like `https://data.examplecommons.org`.
- For the "Authorized redirect URIs" enter `hostname + '/user/login/google/login/'` so for example `https://data.examplecommons.org/user/login/google/login/`.
- Download your credentials with contain the `client_id` and `client_secret`.
- Copy the [variables.template](https://github.com/uc-cdis/cloud-automation/blob/7bfeda73571d2841894470c9fd11027ed8cadd07/tf_files/variables.template) file to somewhere secure and fill it with creds

#### Configure certificate for your domain

For AWS, use the certificate manager to either import the certs or request admin for the domain to allow AWS to generate certs. The domain should match the hostname you configured in Google or the parent domain name.

#### Using the automated scripts

We have two automation scripts:

* [gen3](https://github.com/uc-cdis/cloud-automation/blob/master/gen3/README.md) supports our terraform-based infrastructure automation
* [g3k]

#### Create customized AMI

The latest versions of the customized ubuntu 16.04 AMI's required by the terraform automation
are published as public images under the AWS `cdis-test` account.
Build new AMIs using [images](https://github.com/uc-cdis/images). 

