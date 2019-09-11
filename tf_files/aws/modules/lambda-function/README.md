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

Basically  you'll need an AWS lambda capable function in a path somewhere reacheable. 

This module would zip the provided path and send it to lambda.


## 4. Variables

### 4.1 Required Variables

* `function_file` path to the function file.
* `lambda_function_name` how do you want the funtion to be named.
* `lambda_function_iam_role_arn` role to attach to the function.

### 4.2 Optional Variables

* `lambda_function_description` a brief description of the function.
* `lambda_funtion_env` environmental variables for the function. This is a map type variable.
* `lambda_funtion_handler` handler for the function. Basically it'll be filename(minus the extension).function_name. Defaulted to lambda_function.function_handler.
* `lambda_function_runtime` language the function is going to use. Default python3.7.
* `lambda_function_timeout` how long in seconds for the funtion to declare a timeout. Default 3.
* `lambda_function_memory_size` How much memory will be used in MB. Default 128.
* `lambda_function_tags` tags you want associated with your function. This variable is map type variable.


## 5. Considerations

This module has been coded to use the very basics of a lambda function and sometimes it might not be suitable for certain cases. There are variables that conflict with others, therefore this module can't cover every case.

To know more about which variables can be used and which ones can't mix, visit: https://www.terraform.io/docs/providers/aws/r/lambda_function.html


