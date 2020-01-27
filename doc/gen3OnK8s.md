# TL;DR

You have a kubernetes cluster, and you one to run gen3.

## Overview

This is a basic introduction to the `gen3` cli tools for
deploying [Gen3](https://gen3.org) services on a kubernetes cluster.
The [CTDS](https://ctds.uchicago.edu) manages multiple [Gen3 Commons](https://gen3.org/) running on kubernetes clusters in AWS.
Our internal devops team maintains code in our [cloud-automation](https://github.com/uc-cdis/cloud-automation) repository that automates how we provision infrastructure (using [terraform](https://www.terraform.io)), and configure and deploy our services to [kubernetes](https://kubernetes.io) using our home grown `gen3` cli.
Many of the `gen3` tools are cloud agnostic, and should work well with any kubernetes cluster.

### Gen3 Architecture Quick Intro

Underlying a Gen3 commons are a suite of interdependent services - each exporting a portion of the Gen3 HTTP API, and storing data
in its own data store.  We typically run Gen3 services within 
a kubernetes namespace, and configure the services to store
data in databases maintained outside the kubernetes cluster (for example - postgres databases in [RDS](https://aws.amazon.com/rds/)).
A minimal, but full featured Gen3 infrastructure looks like this:

* a kubernetes cluster running Gen3 services (indexd, fence, arborist, sheepdog, ...)
* a [postgres]() database
* an [elastic search]() database

### One Commons Per User

The `gen3` tools have evolved in an environment where we assume
that single user login on an administrator machine administers a single commons on a kubernetes cluster (running in a [VPC](https://aws.amazon.com/vpc/)) that may be shared by multiple commons administered in different accounts.  

The `gen3` tools therefore assume that the administrative account for
a commons defines an `$GEN3_HOME` environment variable that points to a folder where our `cloud-automation` code is installed.  The `$GEN3_HOME` folder has two sibling folders - a `cdis-manifest` folder holds a [git](https://git-scm.com/) repository for public (not secret) configuration, and a secrets folder that holds another git repository for private (secret) configuration.  The name of the secrets folder is the name of the VPC (defined in the `$vpc_name` environment variable).

## Installation

First, install the dependencies.  
* `bash` (or `zsh` works too) shell and friends (`sed`, `gawk`, ...)
* [git](https://git-scm.com/)
* [jq](https://stedolan.github.io/jq/manual/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [aws cli](https://aws.amazon.com/cli/) if running in AWS

Next, install the `gen3` tools, and configure your shell (`bash` or `zsh`) to work with them:

```
export vpc_name=YOUR_CLUSTER_NAME  # set an alphanumeric name
git clone https://github.com/uc-cdis/cloud-automation.git
(
  cd cloud-automation
  cat - >> /tmp/.bashrc <<EOM
export vpc_name="${vpc_name}";
export GEN3_HOME="$(pwd)";
source "\${GEN3_HOME}/gen3/gen3setup.sh";
EOM
)
eval "$(tail -2 /tmp/.bashrc)"
```

The `gen3` CLI should now be enabled in your shell.
`gen3 help`

## Configuration

The `gen3` tools support a [gitops](https://www.gitops.tech/) 
configuration process which assumes that public configuration is 
saved in a `cdis-manifest` git repository (like this [one](https://github.com/uc-cdis/cdis-manifest)), and secret configuration is saved in a git repository under the `$vpc_name` sibling folder.

```
$ ls -1Fd cloud-automation cdis-manifest $vpc_name
bhcprodv2/
cdis-manifest/
cloud-automation/
```

Before we can launch Gen3 services, we must first prepare the
configuration that those services require.

### 00configmap.yaml



## CICD with gen3

