# TL;DR

This module will create an sns topic and lambda for elasticsearch alarms. 


## 1. QuickStart

```
gen3 workon <profile> <commons_name>_es
```

Ex.
```
$ gen3 workon cdistest emalinowskiv1_es
```

## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overview](#3-overview)
- [4. Variables](#4-Variables)
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

## 4. Variables

### Required
* `slack_webhook` The webhook url for slack. It will use this to send the alarms to slack. This can be obatained from the slack app page, under incoming-webhooks. 
* `vpc_name` This is name of the vpc. It is used to be able to tell the alarms apart within cloudwatch and within slack.
### Optional 
* `Alarm Threshold` The percentage the storage space needs to exceed for an alarm to occur. The default is set to 85% but can be overridden within the config.tfvars file.


## 5. Considerations

* This module has been added to the standard elasticsearch terraform deploy so most of the variables should be setup when terraform is run. The only required variable at that point would be the slack_webhook.
