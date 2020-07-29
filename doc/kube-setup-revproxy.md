# TL;DR

Configure and launch the reverse proxy.  

## References

* the reverse proxy [readme](../kube/services/revproxy/README.md) has more details.
* WAF - the reverse proxy deploys the [modsecurity web application firewall](./waf.md).
* [maintenance mode](./maintenance.md)
* the [ip blacklist](../gen3/lib/manifestDefaults/revproxy/) may be configured with a custom `manifests/revproxy/blacklist.conf`
