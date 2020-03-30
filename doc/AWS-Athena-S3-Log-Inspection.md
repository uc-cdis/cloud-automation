# TL;DR

This would try to explain how to interact with Athena in order to obtain information from logs located in S3. Athena lets you use SQL language to gather information stored in buckets. For example bucket access logs, etc.

## 1. QuickStart

```
aws athena start-query-execution --query-string 'select * from s3_access_logs_db.mybucket_logs limit 5;'\
   --query-execution-context Database=test45 \
   --result-configuration OutputLocation=s3://test/ \
   --output text
```

The above command would give you the last rows for the query passed along. However, this README would only contain examples on how to work with Athena from the console.


## 2. Table of content

- [1. QuickStart](#1-quickstart)
- [2. Table of Contents](#2-table-of-contents)
- [3. Getting Started](#3-getting-started)
  - [3.1 Create Database Single Bucket](#31-create-database-single-bucket)
  - [3.1 Create Database Multiple Buckets](#31-create-database-multiple-buckets)
- [4. Query Data](#4-query-data)



## 3. Getting Started


### 3.1 Create Database Single Bucket

To analyze the S3 access logs in AWS Athena, create the database:
```
CREATE DATABASE IF NOT EXISTS s3_access_logs_db
```

If you have a single log bucket, create the table without partition:
```
CREATE EXTERNAL TABLE IF NOT EXISTS s3_access_logs_db.mybucket_logs(
  BucketOwner STRING,
  Bucket STRING,
  RequestDateTime STRING,
  RemoteIP STRING,
  Requester STRING,
  RequestID STRING,
  Operation STRING,
  Key STRING,
  RequestURI_operation STRING,
  RequestURI_key STRING,
  RequestURI_httpProtoversion STRING,
  HTTPstatus STRING,
  ErrorCode STRING,
  BytesSent BIGINT,
  ObjectSize BIGINT,
  TotalTime STRING,
  TurnAroundTime STRING,
  Referrer STRING,
  UserAgent STRING,
  VersionId STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
'serialization.format' = '1',
  'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) \\\"([^ ]*) ([^ ]*) (- |[^ ]*)\\\" (-|[0-9]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (\"[^\"]*\") ([^ ]*)$'
)LOCATION 's3://target-bucket-name/prefix/'
```


### 3.1 Create Database Multiple Buckets

If you have multiple logs bucket, create the table partitioned by log bucket name, choose one of the buckets as a placeholder LOCATION:
```
CREATE EXTERNAL TABLE IF NOT EXISTS s3_access_logs_db.mybucket_logs(
  BucketOwner STRING,
  Bucket STRING,
  RequestDateTime STRING,
  RemoteIP STRING,
  Requester STRING,
  RequestID STRING,
  Operation STRING,
  Key STRING,
  RequestURI_operation STRING,
  RequestURI_key STRING,
  RequestURI_httpProtoversion STRING,
  HTTPstatus STRING,
  ErrorCode STRING,
  BytesSent BIGINT,
  ObjectSize BIGINT,
  TotalTime STRING,
  TurnAroundTime STRING,
  Referrer STRING,
  UserAgent STRING,
  VersionId STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
PARTITIONED BY (LogBucket STRING)
WITH SERDEPROPERTIES (
'serialization.format' = '1',
  'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) \\\"([^ ]*) ([^ ]*) (- |[^ ]*)\\\" (-|[0-9]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (\"[^\"]*\") ([^ ]*)$'
)LOCATION 's3://target-bucket-name/'

```
Then add each log bucket as a partition, one by one:
```
ALTER TABLE s3_access_logs_db.mybucket_logs ADD PARTITION
(logbucket='target-bucket-name') LOCATION 's3://target-bucket-name/';
```


## 4. Query Data

Example 1:

This query would show you a list of total bytes downloaded by user
```
with dataset as (SELECT requestdatetime, bytessent, bucket, split_part("requesturi_key", '?', 1) as key, regexp_extract("requesturi_key", 'username=(.+)&', 1) as username FROM "s3_access_logs_db"."mybucket_logs" WHERE requesturi_operation = 'GET' and requester = 'arn:aws:iam::YYYY:user/fence-bot') select sum(bytessent) as totalbytes, username from dataset group by username

```

Example 2:


The following query would be useful to list a specific file download actions
```
select requestdatetime,remoteip, requesturi_operation, useragent, split_part("requesturi_key", '?', 1) as key, regexp_extract("requesturi_key", 'username=(.+)&', 1) as username from s3_access_logs_db.mybucket_logs where key like '%FILENAME.EXT%' and requesturi_operation='GET' order by requestdatetime
```

