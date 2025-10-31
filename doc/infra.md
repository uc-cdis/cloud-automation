# TL;DR

Kubernetes batch job helper

## Use

```
bash infra.sh sub-command options
```

Sub-commands:

### ec2-list
### es-list
### rds-list
### s3-list
### subnet-list
### vpc-list
### json2csv flat json to csv

see https://support.google.com/docs/answer/6325535?hl=en

Ex:

```
gen3 infra ec2-list
gen3 infra ec2-list | gen3 infra json2csv
```
