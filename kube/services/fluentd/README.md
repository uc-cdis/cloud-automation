# TL;DR

Fluentd would let us send containers and kubelet logs to cloudwatch.

# Fluentd details

Fluend is a daemonset that runs in the kube-system namespace and would mount 
`/var/log` and `/var/lib/docker/containers` on the pod from the node and send 
the content up to CloudWatch Logs.

## AWS Role

The kubernetes worker nodes require an AWS role that allows fluentd to talk to cloudwatchlog, 
they need basically list,read, and write access.

## fluentd setup

Once the daemonset is up, logs should start populating cloudwatch under the fluentd 
Log group, unless changed in the yaml file for something different. If the group does 
not exist, then it'll be automatically created if the role has the right permissions obviously.

## More information

https://www.fluentd.org/

(This is what we used as base but edited it to use cloudwatch instead of elastic search)
https://github.com/fluent/fluentd-kubernetes-daemonset/blob/master/fluentd-daemonset-elasticsearch.yaml

List of images available
https://hub.docker.com/r/fluent/fluentd-kubernetes-daemonset/tags/

# Gen3 Log Processing

## Gen3 Log Stream in AWS

In AWS logs for each gen3 commons accumulate in the CSOC account via a multi-part log stream 
that traverses several [infrastructure components](../../../tf_files/aws/modules/common-logging):

* fluentd generates a json record from each log line emitted by a pod, and deposits that record into a 
[CloudWatch Logs Group](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)
* Cloudwatch publishes each log record to a [Kinesis data stream](https://aws.amazon.com/kinesis/data-streams/)
* A [Lambda](https://aws.amazon.com/lambda/) function in the CSOC account subscribes to the log stream, and forwards each log record to a [Kinesis firehose](https://aws.amazon.com/kinesis/data-firehose/) that deposits the record into an
[Elastic Search](https://aws.amazon.com/elasticsearch-service/) cluster and [S3 buckets](https://aws.amazon.com/s3/) in the CSOC dedicated to log storage and analysis.

## Log Parsing

We augment the default fluent kubernetes configuration to parse the various gen3 log formats to extract from each log line structured data that augments fluentd's json record for that log line with new key-value pairs that are more easily queried in elastic search.

### Debugging Fluentd Config

One way to test fluentd locally is to just launch the docker image locally,
and mount local drives, and interactively launch fluentd, and observe how it processes
sample log files - ex:

```
laptop # source dockerTest.sh
laptop # fluentd_run
$ cd /fluent/etc
$ cp fluet.conf fluent.conf.bak
$ cp /gen3/test.conf ./fluent.conf
$ fluentd -c /fluentd/etc/${FLUENTD_CONF} -p /fluentd/plugins --gemfile /fluentd/Gemfile -v --dry-run
$ fluentd -c /fluentd/etc/${FLUENTD_CONF} -p /fluentd/plugins --gemfile /fluentd/Gemfile -v
```
Then on the laptop
```
laptop # source dockerTest.sh
laptop # fluentd_log 'sample log line' | tee -a varlogs/sample.log
laptop # fluentd_log '172.24.73.244 - - [24/Oct/2018:20:58:04 +0000] "GET /jwt/keys HTTP/1.1" 200 2139 "-" "kube-probe/1.10"' | tee -a varlogs/sample.log
laptop # fluentd_log '{"gen3log":"nginx", "reuben":"frickjack", "number":55 }' | tee -a varlogs/sample.log
```

## Log Analysis with Elastic Search

A kibana frontend to gen3's AWS elastic search logs cluster is accessible through the production VPN at [http://kibana.planx-pla.net/_plugin/kibana](http://kibana.planx-pla.net/_plugin/kibana),
and requires authentication via LastPass.
