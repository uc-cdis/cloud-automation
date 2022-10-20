# TL;DR

Create an AWS IAM role based on a set of variables passed along


## 1. QuickStart

This module by itself won't do much, the main purpose is to be used in other modules and avoid repeating code.


```
module "role-for-lambda" {
  source                       = "../iam-role/"
  role_name                    = "${var.account_name}-security-alert-role"
  role_description             = "Role for the alerting lambda function"
  role_assume_role_policy      = <<EOP
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOP
}
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

You must have a trusted relationship configuration in json format for the assume role policy.


## 4. Variables

### 4.1 Required Variables

* `role_name` name to give the role.
* `role_assume_role_policy` for the trusted relationship.


### 4.2 Optional Variables

* `role_description` brief description of the role.
* `role_tags` tag to associate to the role. This is a map type variable.
* `role_force_detach_policies` specifies to force detaching any policies the role has before destroying it. Defaults to false.


## 5. Considerations

This module has been coded to use the very basics of a lambda function and sometimes it might not be suitable for certain cases. There are variables that conflict with others, therefore this module can't cover every case.

To know more about which variables can be used and which ones can't mix, visit https://www.terraform.io/docs/providers/aws/r/iam_role.html
