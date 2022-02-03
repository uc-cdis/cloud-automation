# TL;DR

Create and interact with AWS SQS queues.

## Use

### info

Returns the SQS URL for the provided SQS.
```
   gen3 sqs info <sqsName>
```
Options:
  - sqsName: name of SQS to fetch the URL for.

### create-queue

Creates a new SQS queue, along with 2 policies to push and pull from the queue. Returns an SQS URL and the policies ARNs.
```
  gen3 s3 create-queue <sqsName>
```
Options:
  - sqsName: name of SQS to create.
