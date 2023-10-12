# TL;DR

Deploy an AWS policy document


## 1. QuickStart

This module by itself won't do much, the main purpose is to be used in other modules and avoid repeating code.

Ex:

```
module "rolex-policy" {
  policy_name        = "policy-x"
  policy_path        = "/"
  policy_description = "Let the y resource access z"
  policy_json        = <<EOP
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutRetentionPolicy",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::123456789012:role/adminvm"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::098765432109:role/adminvm"
        }
    ]
}
EOP
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

Create a policy with the given permissions 



## 4. Variables

### 4.1 Required Variables

* `policy_name` name for the policy.
* `policy_path` path in which to create the policy.
* `policy_json` the actual policy.


### 4.2 Optional Variables

* `policy_description` Description for the policy.

