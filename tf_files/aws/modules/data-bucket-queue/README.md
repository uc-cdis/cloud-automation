# TL;DR

This module would bring up a fully functional SNS service listens to data upload S3 bucket and SQS queue subscribe to the SNS.
If everything goes as expected, we will receive the message when we upload object to S3 bucket and indexD listener will grab message from the sqs.


## 1. QuickStart

```
gen3 workon <profile> <commons_name>
```

Ex.
```
$ gen3 workon cdistest diwv1
```

## 2. Policy

SNS policy which is granted to access data upload S3 bucket is setup along with SNS in terraform.
Worker nodes to access SQS policy will be added in `_eks` module.

## 3. Overview

This module contains SNS and SQS aws services.
The S3 event is setup in `upload-data-bucket` module.
