# TL;DR

Fluentd would let us send containers and kubelet logs to cloudwatch

# Some details

Fluend is a daemonset that runs in the kube-system namespace and would mount 
`/var/log` and `/var/lib/docker/containers` on the pod from the node and send 
the content up to CloudWatch Logs.

# To keep in mind

Roles should be used for the nodes to be able to talk to cloudwatchlog, 
they need basically list,read, and write access.

# fluentd setup

Once the daemonset is up, logs should start populating cloudwatch under the fluentd 
Log group, unless changed in the yaml file for something different. If the group does 
not exist, then it'll be automatically created if the role has the right permissions obviously.

# More information

https://www.fluentd.org/

(This is what we used as base but edited it to use cloudwatch instead of elastic search)
https://github.com/fluent/fluentd-kubernetes-daemonset/blob/master/fluentd-daemonset-elasticsearch.yaml

List of images available
https://hub.docker.com/r/fluent/fluentd-kubernetes-daemonset/tags/
