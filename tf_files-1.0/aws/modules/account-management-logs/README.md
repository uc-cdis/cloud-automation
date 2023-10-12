# TL;DR

Create a cloudtrail to send management logs onto S3 and Cloudwatch for an specific account. Also hook the CloudWatchLogGroup created to the CSOC account through a Subscription filter.

2019-09-11
This module would also deploy a set of security alarms based on Cloudwatch Alerts.

## 1. QuickStart

```
gen3 workon <profile> <profile>_management-logs
```

## 2. Table of Contents

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Overiew](#3-overview)
- [4. Variables](#4-variables)
  - [4.1 Required Variables](#41-required-variables)
  - [4.2 Optional Variables](#42-optional-variables)
- [5. Considerations](#5-considerations)


## 3. Overview

Once you workon the workspace, you may want to edit the config.tfvars accordingly.

Ex.
```
csoc_account_id = "433568766270"
account_name = "something"
```

## 4. Variables

### 4.1 Required Variables

* `account_name` name of the account running the module, most likely the same name as the profile.
* `csoc_account_id` id of the CSOC account. This is set by default to 433568766270, and there is no need to put it in the config.tfvars file unless you are actually using  a different CSOC account.

### 4.2 Optional Variables

none

## 5. Considerations

Everything mus be properly set in the CSOC account, please refer to the `management-logs` module (without the account at the beginning).
