# TL;DR

Run the bucket-size-report script, to calculate bucket sizes.

## Overview

This script is used to calculate the size of each bucket in the current account.
The script also can be run as a job, which can be used to find bucket sizes
across different account.

## As Script

### gen3 bucket-size report

``` bash
ex:
gen3 bucket-size-report
```

Run the bucket-size-report script, to calculate bucket sizes.

## As Job

### Job Setup

To setup the job you will need to create a g3auto secret for the job to use. 
As of now this is a manual process where you will need to run the following.

``` bash
mkdir {SecretsFolder}/g3auto/bucket-size-report
touch {SecretsFolder}/g3auto/bucket-size-report/creds.json
touch {SecretsFolder}/g3auto/bucket-size-report/ses-creds.json
```

After creating the files you will want to add the information similar to the following

creds.json

``` json
{
  "credentials": [
    {
      "aws_access_key_id": "",
      "aws_secret_key: ""
    }
  ]
}
```

ses-creds.json

``` json
{
  "aws_access_key_id": "",
  "aws_secret_key": "",
  "sender": "",
  "recipient": ""
}
```

Note that the creds.json file has an array for the credentials block. This is because you can put in multiple blocks of credentials, 
which will allow you to get the size report of multiple environments... useful as a cronjob with environments that contain buckets
in multiple accounts. The ses-creds sender/recipient keys should contain an email adress of the sender/reviever of the email. Please
be aware that these emails will need to be valided in SES in the account with the given credentials before they can be used. Once
these are setup you will also need to ensure they are a kubernetes secret by running the kube-setup-secrets script.

### gen3 job run bucket-size-report

``` bash
ex:
gen3 job run bucket-size-report
```

Run the bucket-size-report script, to calculate bucket sizes.

