# TL;DR

You have a kubernetes cluster, and you want to run gen3.

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
* a [postgres](https://www.postgresql.org/) database
* an [elastic search](https://www.elastic.co/) database

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
saved in a `cdis-manifest` git repository (like this [one](https://github.com/uc-cdis/cdis-manifest)), and secret configuration is saved in a git repository under the `Gen3Secrets` folder (or `$vpc_name/` in legacy commons) sibling folder.

```
$ ls -1Fd cloud-automation cdis-manifest Gen3Secrets
Gen3Secrets/
cdis-manifest/
cloud-automation/
```

Before we can launch Gen3 services, we must first prepare the
configuration that those services require.

### Gen3Secrets/

There are 3 main secrets that must be manually configured.

#### global configmap - 00configmap.yaml

Save a `Gen3Secrets/00configmap.yaml` with proper configuration for your environment:
```
$ cat 00configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: global
data:
  environment: devplanetv1
  hostname: demo.planx-pla.net
  revproxy_arn: arn:aws:acm:us-east-1:707767160287:certificate/c676c81c-9546-4e9a-9a72-725dd3912bc8
  slack_webhook: None

$ kubectl apply -f 00configmap.yaml
```

* `environment` - name unique to the kubernetes cluster (the whole cluster - not just the namespace)
* `hostname` - public domain of the gen3 instance
* `revproxy_arn` - in AWS - the ARN of the ACM SSL certificate corresponding to `hostname`

### g3auto/dbfarm/servers.json

The `gen3` automation assumes a cluster runs a database farm of one or more postgresql servers in which new databases may be created on demand.  The `dbfarm/server.json` file holds administrator credentials for each server that can create new databases and users on each server.  For example:

```
$ cat g3auto/dbfarm/servers.json 
{
  "server1": {
    "db_host": "devplanetv1-fencedb.cwvizkxhzjt8.us-east-1.rds.amazonaws.com",
    "db_username": "fence_user",
    "db_password": "XXXXXXX",
    "db_database": "template1",
    "farmEnabled": true
  },
  "server2": {
    "db_host": "devplanetv1-indexddb.cwvizkxhzjt8.us-east-1.rds.amazonaws.com",
    "db_username": "indexd_user",
    "db_password": "XXXXXXXXX",
    "db_database": "template1",
    "farmEnabled": true
  }
}
```

### apis_configs/fence-config.yaml

A template for the `fence` configuration file is available [here](https://github.com/uc-cdis/fence/blob/master/fence/config-default.yaml).  It is also possible to save the public (not secret) parts (root keys) of the configuration in `cdis-manifest/hostname/manifests/fence/fence-config-public.yaml`.

### creds.json

The `creds.json` file includes database secrets for the core (legacy) gen3 services.  The full details of `creds.json` are outside the scope of this document.

```
{
  "fence": {
    "note": "legacy not used, but still must exist for now"
  },
  "sheepdog": {
    "db_host": "devplanetv1-gdcapidb.rds.amazonaws.com",
    "db_username": "sheepdog",
    "db_password": "XXXXXXXXXX",
    "db_database": "reuben",
    "gdcapi_secret_key": "XXXXXXXX",
    "indexd_password": "XXXXXXXX",
    "hostname": "reuben.planx-pla.net"
  },
  "peregrine": {
    "db_host": "devplanetv1-gdcapidb.rds.amazonaws.com",
    "db_username": "peregrine",
    "db_password": "XXXXXXXXX",
    "db_database": "reuben",
    "gdcapi_secret_key": "XXXXXXXXXXX",
    "hostname": "reuben.planx-pla.net"
  },
  "indexd": {
    "db_host": "devplanetv1-indexddb.rds.amazonaws.com",
    "db_username": "indexd_user",
    "db_password": "XXXXXXXX",
    "db_database": "reuben",
    "user_db": {
      "fence": "XXXXXXX",
      "gdcapi": "XXXXXX",
      "gateway": "XXXXXXXXX"
    }
  },
  "es": {
    "aws_access_key_id": "XXXXX",
    "aws_secret_access_key": "XXXXXXXXX"
  },
  "ssjdispatcher-from-zlchitty": {
    "AWS": {
      "region": "us-east-1",
      "user_name": "test_ssjdispatcher",
      "aws_access_key_id": "XXXXXXX",
      "aws_secret_access_key": "XXXXXXXX"
    },
    "SQS": {
      "url": "https://sqs.us-east-1.amazonaws.com/707767160287/zoe-dataupload"
    },
    "JOBS": [
      {
        "name": "indexing",
        "pattern": "s3://devplanetv1-data-bucket/*",
        "imageConfig": {
          "url": "http://indexd-service/index",
          "username": "gdcapi",
          "password": "XXXXXXXX"
        },
        "RequestCPU": "500m",
        "RequestMem": "0.5Gi"
      }
    ]
  }
}

```


### cdis-manifest/hostname/ configuration

The `cdis-manifest/` folder holds a clone of a manifest repository 
like this [one](https://github.com/uc-cdis/cdis-manifest).  
Each git repository holds configuration for multiple commons.  The `gen3` tools
use the hostname from the glob configmap to determine which `cdis-manifest/`
subfolder applies - ex: `cdis-manifest/demo.planx-pla.net/`.

The manifest folder includes at least the following configuration.

#### manifest.json

A typical gen3 deployment has a `manifest.json` like [this](https://github.com/uc-cdis/cdis-manifest/blob/master/caninedc.org/manifest.json) the specifies various details about the commons including the versions of different gen3 services to deploy and the dictionary metadata schema.  The details of how to build a manifest are beyond the scope of this document.

#### ETL Mapping

The [etl mapping](https://github.com/uc-cdis/cdis-manifest/blob/master/caninedc.org/etlMapping.yaml)

#### portal/gitops.json

The gen3 windmill UX has a sophisticated [configuration](https://github.com/uc-cdis/cdis-manifest/blob/master/caninedc.org/portal/gitops.json) that allows it to work with various dictionary and ETL configurations.


## CICD with gen3

We keep the master copy of our secrets on our admin vm, so most of the `gen3` tools are configured to treat `Gen3Secrets/` as read-only when the `JENKINS_HOME` environment variable is set.  A simple CICD flow can be setup as a cron job on the kubernetes cluster or in Jenkins or some similar system like this:

```
export JENKINS_HOME=offadmin
git clone cloud-automation
git clone cdis-manifest
export GEN3_HOME=$(pwd)/cloud-automation
source $GEN3_HOME/gen3/gen3setup.sh
if some_configuration_has_changed; then
  gen3 roll all
fi
```

## Interacting with Databases

The [gen3 db](./db.md) tools automate the creation of postres databases and the generation of new configuration artifacts.  For most postgres backed services we can interact with the service database with `gen3 db psql` (also aliased as `gen3 psql`).  Ex:

```
gen3 psql fence
```

## Batch Jobs

The [gen3 job](./job.md) tools help launch kubernetes batch jobs by processing the templates under `kube/services/jobs/`.

Ex:
```
gen3 job run usersync
gen3 job logs usersync
gen3 job run healthcheck-cronjob
```
