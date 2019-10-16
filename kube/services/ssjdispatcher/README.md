# ssjdispatcher
The SQS S3 Job Dispatcher is designed for centralizing all gen3 jobs. It monitors a SQS queue receiveing CRUD messages from S3 buckets and determine an action basing on the object url pattern.

### Create service in new Commons
To create the service in a Commons that doesn't have ssjdispatcher before, you will need to:
```
PULL LATEST CLOUD-AUTOMATION
kubectl delete secret ssjdispatcher-creds
gen3 kube-setup-networkpolicy
gen3 kube-setup-ssjdispatcher
```
