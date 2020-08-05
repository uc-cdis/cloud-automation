# How to setup the indexd listener for the data upload flow

- [Set up a SQS that will receive messages when a file is uploaded to a bucket](https://github.com/uc-cdis/cloud-automation/blob/master/tf_files/aws/modules/data-bucket-queue/README.md)
- Grant sqs permission to `fence-bot` user (currently we are using this user for the job)

- Edit the manifest and add:
  - add json block for dispatcher service:
  ```
  "ssjdispatcher": {
    "job_images": {
      "indexing": "quay.io/cdis/indexs3client:master"
    }
  }
  ```
  - in `versions`:
`"ssjdispatcher": "quay.io/cdis/ssjdispatcher:master"`
  - in `global`:
`"dispatcher_job_num": "10"`

- Edit the fence-config and add:
  - in `AWS_CREDENTIALS:` add the IAM which will be used to access the s3 bucket:
```
EXAMPLE:
  'fence-bot':
    'aws_access_key_id': '********'
    'aws_secret_access_key': '*********'
```
  - in `S3_BUCKETS` add the bucket name and the IAM:
```
EXAMPLE:
S3_BUCKETS:
  # for data upload:
  'diwv1-data-bucket':
    'cred': 'fence-bot'
    
# `DATA_UPLOAD_BUCKET` specifies an S3 bucket to which data files are uploaded,
# using the `/data/upload` endpoint. This must be one of the first keys under
# `S3_BUCKETS` (since these are the buckets fence has credentials for).
DATA_UPLOAD_BUCKET: 'diwv1-data-bucket'
```
- Edit `creds.json` to configure the ssjdispatcher by adding the following block, and:

  - Fill up the  AWS region and credentials;
      - If you are setting up your dev env, these should be for the `test_ssjdispatcher` user
  - Fill up the indexd username (`gdcapi`) and password;
      - Copy the password from an existing `indexd_password` field
  - Fill up the SQS url;
  - Replace `BUCKET_NAME` in the job pattern by the name of the bucket used for storing the uploaded files.

```
"ssjdispatcher": {
"AWS": {
  "region": "",
  "aws_access_key_id" : "",
  "aws_secret_access_key": ""
},
"SQS": {
  "url": ""
},
"JOBS": [
  {
    "name": "indexing",
    "pattern": "s3://BUCKET_NAME/*",
    "imageConfig": {
      "url": "http://indexd-service/index",
      "username": "",
      "password": ""
    },
    "RequestCPU": "500m",
    "RequestMem": "0.5Gi"
  }
]
}
```

- Pull the latest `cloud automation` or make sure you have the ssjdispatcher files.
- Run the following commands:
    - `kubectl delete secret ssjdispatcher-creds`
    - `gen3 kube-setup-secrets`
    - `gen3 kube-setup-networkpolicy`
    - `gen3 kube-setup-ssjdispatcher`
