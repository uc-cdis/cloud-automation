# TL;DR

This module would bring up a fully functional SNS service listens to data upload S3 bucket and SQS queue subscribe to the SNS.
If everything goes as expected, we will receive the message when we upload object to S3 bucket and indexD listener will grab message from the sqs.


## 1. QuickStart

```
gen3 workon <profile> <bucket_name>__data-bucket-queue
```

Ex.
```
$ gen3 workon cdistest diwv1-bucket__data-bucket-queue
```

## 2. Policy

SNS policy which is granted to access data upload S3 bucket is setup along with SNS in terraform.


## 3. Overview

This module contains SNS and SQS aws services, and 
The S3 event is also setup, unless the `configure_bucket_notifications` variable is set false (as in the `upload-data-bucket` module).

## Deploy

The `ssjdispatcher` interacts with the SQS queue using `fence_bot` credentials.  The `fence_bot` policy must be manually updated to access the queue, and the `ssjdispatcher` configuration requires the queue ARN.