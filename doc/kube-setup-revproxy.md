# TL;DR

Configure and launch the reverse proxy.  

## References

* the reverse proxy [readme](../kube/services/revproxy/README.md) has more details.
* WAF - the reverse proxy deploys the [modsecurity web application firewall](./waf.md).
* IMPORTANT: The modsecurity WAF and Revproxy ELB service is only deployed if the "deploy_elb" flag is set to true in the manifest-global configmap. The Revproxy ELB is now deprecated- we suggest deploying an AWS ALB instead (please see kube-setup-ingress script)
* Please see https://github.com/uc-cdis/cloud-automation/blob/master/doc/kube-setup-ingress.md as AWS WAF and ALB is recommended. 
* [maintenance mode](./maintenance.md)
* the [ip blacklist](../gen3/lib/manifestDefaults/revproxy/) may be configured with a custom `manifests/revproxy/blacklist.conf`
