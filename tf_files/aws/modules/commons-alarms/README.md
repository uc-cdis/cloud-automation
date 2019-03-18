# TL;DR

This module will create an sns topic and lambda for commons alarms. Currently there are only postgres rds alarms created but you can add a new .tf file to create alarms for other services.


## 1. QuickStart

```
gen3 workon <profile> <commons_name>
```

Ex.
```
$ gen3 workon cdistest emalinowskiv1
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4 Required Variables for Alarms](#4-required-variables)
- [5. Considerations](#5-considerations)



## 3. Overview

Once you workon the workspace, you will want to edit the config.tfvars accordingly.

There are mandatory variables, and there are a few other optionals that are set by default in the variables.tf file, but you could change them accordingly.

Ex.
```
emalinowskiv1@cdistest_admin ~ % cat .local/share/gen3/cdistest/emalinowskiv1/config.tfvars
vpc_name   = "emaliinowskiv1"
slack_webhook = https://hooks.slack.com/services/XXXXXXXX/XXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXX
```

## 4 Required Variables

* `db_size` The size of the database in GB. Cloudwatch does not have a metric for total disk size so the db size is needed to get the disk usage percentage.
* `slack_webhook` The webhook url for slack. It will use this to send the alarms to slack. This can be obatained from the slack app page, under incoming-webhooks. 
* `vpc_name` This is name of the vpc. It is used to be able to tell the alarms apart within cloudwatch and within slack.
* `db_fence` This is the identifier for the fence db. It is used so that an alarm can be created for the specific database.
* `db_indexd` This is the identifier for the indexd db. It is used so that an alarm can be created for the specific database.
* `db_gdcapi` This is the identifier for the gdcapi db. It is used so that an alarm can be created for the specific database.

## 5. Considerations

* This module has been added to the standard commons terraform deploy so most of the variables should be setup when terraform is run. The only required variable at that point would be the slack_webhook. 
