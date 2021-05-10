# TL;DR

Create an AWS SQS queue, along with 2 policies to push and pull from the queue.

## 1. Table of Contents

- [1. Table of Contents](#1-table-of-contents)
- [2. Variables](#2-variables)
  - [2.1 Required Variables](#21-required-variables)
- [3. Outputs](#3-outputs)

## 2. Variables

### 2.1 Required Variables

* `sqs_name` name for the SQS.

## 3. Outputs

| Name | Description |
|------|-------------|
| sqs-url | URL for the new SQS |
| send-message-arn | ARN for the policy to push messages to the SQS (access: `SendMessage`) |
| receive-message-arn | ARN for the policy to pull messages from the SQS (access: `ReceiveMessage`, `GetQueueAttributes`, `DeleteMessage`) |
