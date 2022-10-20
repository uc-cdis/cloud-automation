# TL;DR

Deploy a lambda function given certain variables

## 1. QuickStart

This module by itself won't do much, the main purpose is to be used in other modules and avoid repeating code.

Ex:

```
module "alerting-lambda" {
  source                       = "../lambda-function/"
  function_file                = "${path.module}/../../../../files/lambda/security_alerts.py"
  lambda_function_name         = "${var.account_name}-security-alert-lambda"
  lambda_function_description  = "Checking for things that should or might not happend"
  lambda_function_iam_role_arn = "${module.role-for-lambda.role_arn}"
  lambda_function_env          = {"topic"="arn:aws:sns:us-east-1:433568766270:planx-csoc-alerts-for-bsd-security"}
  lambda_function_handler      = "security_alerts.lambda_handler"
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

Basically you'll need an AWS lambda capable function in a path somewhere reacheable. 

This module would zip the provided path and send it to lambda.


## 4. Variables

### 4.1 Required Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| function_file | Path to the function file | string | |
| lambda_function_name | The name you want for the lambda function | String | |
| lambda_function_iam_role_arn | ARN of the role you want attached to the function | string | |
| lambda_function_env | Environmental variables for your funtion | list | [] |


### 4.2 Optional Variables

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| lambda_function_description | A brief description for your lambda function | string | "" |
| lambda_function_handler | Handler of the fuction | string | lambda_function.function_handler |
| lambda_function_runtime | Language that the function will run | string | python 3.7 |
| lambda_function_timeout | How long in seconds for the function to declare a timeout | number | 3 |
| lambda_function_memory | Maximum amount of memoryi, in Mb, the function will consume upon execution. | number | 128 |
| lambda_function_tags | Tags you want the function associated with. | map | {} |
| lambda_function_with_vpc | Should the function be deployed within a VPC only | boolean | false | 
| lambda_function_security_groups | Security group to associate the function with. Only works if the function is deployed within a VPC | list | [] |
| lambda_function_subnets_id | Subnets wihthing the VPC the function will belong to | list | [] | 

## 5. Considerations

This module has been coded to use the very basics of a lambda function and sometimes it might not be suitable for certain cases. There are variables that conflict with others, therefore this module can't cover every case.

To know more about which variables can be used and which ones can't mix, visit: https://www.terraform.io/docs/providers/aws/r/lambda_function.html


