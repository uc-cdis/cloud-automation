# TL;DR

The es module is intended to spin up a new AWS ElasticSearch cluster within a specific VPC. No permissions are set at all, therefore it worth nothing to leave it there all alone.

Later in the process of building the kubernetes cluster, permissions would be added for a pod to access the ES cluster over a aws-es-proxy (https://github.com/abutaha/aws-es-proxy).


## 1. QuickStart

```
gen3 workon <profile> <commons_name>_es
```

Ex.
```
$ gen3 workon cdistest test-commons_es
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Considerations](#5-considerations)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly. However, assuming you used the example above, you may not need to. You must check the file nonetheless.

Ex.
```
$ cat ~/.local/share/gen3/cdistest/test-commons_es/config.tfvars
vpc_name   = "test-commons"
```

## 4. Variables

### 4.1 Required Variabes

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| vpc_name | The name of the commons you are deploying ES for | string | |


By default the vpc_name variable is filled up by gen3 with the name of the commons used at the moment of workon.


### 4.2 Optional Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| instance_type | Which instance type to use for the cluster | string | "m4.large.elasticsearch" |
| ebs_volume_size_gb | Size of the volume for the instances | number | 20 |
| encryption | Whether or not to encrypt the volumes | boolean | string | "true" |
| instance_count | Number of instances to deploy in the cluster | number | 3 |
| organization_name | For tagging purposes | string | Basic Services |
| es_version | Version to deploy | String | "6.8" | 
| es_linked_role | Whether or not deploy a linked role for the cluster, useful if having multiple clusters in one account | boolean | true |
| slack_webhook | Webhook to send storage usage alerts | string | "" |
| secondary_slack_webhook | A secondary hook for alerting | string | "" |



## 5. Considerations

Should you not want to deploy a big cluster you may want to play with `instance_count`.

`instance_count` default value is 3, therefore a cluster with three instances will be deployed unless you change the value to something else. 1 would work just fine.

