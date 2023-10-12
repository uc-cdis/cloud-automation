# TL;DR

This module would create an SNS topic for notifications.


## 1. QuickStart

```
gen3 workon <profile> <commons_name>_sns
```

Ex.
```
$ gen3 workon cdistest fauziv1_sns
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
- [5. After Deployment](#5-after-deployment)



## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex.
```
vpc_name  = "fauziv1"
cluster_type = "EKS"
emails = ["someone@uchicago.edu","otherone@uchicago.edu"]
topic_display = "Cronjob Monitor"
```

## 4. Variables

### 4.1 Required Variables

* `vpc_name` usually the same name as the commons, this VPC must be an existing one, otherwise the execution will fail. Additionally, it worth mentioning that logging and VPC must exist before running this.
* `cluster_type` EKS or kube-aws
* `emails` List of emails the topic will send message to. More can be added later.
* `topic_display` Subject of the email sent


## 5. After Deployment

Once SNS resources are stood up, then you should be able to apply the jobs into kubernetes.

Jobs compatible with this modules will have `monitored.yaml` at the end of the filename.


