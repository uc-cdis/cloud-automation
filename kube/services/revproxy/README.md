## TL;DR

External facing services are accessed this reverse proxy under subdirectories of the same domain name.

### Run reverse proxy

- Create a cert in AWS Certificate Manager, and register it in the global config map.  This will require the admin for the domain approve it through email
- `gen3 kube-setup-revproxy`
- change the load balancer settings in AWS to use "Listeners->Cipher for port 443->ELBSecurityPolicy-TLS-1-2-2017-01" [issue 151](https://github.com/kubernetes/kubernetes/issues/43744)
- update DNS to point to your ELB

### Nginx resolver

We leverage the nginx DNS resolver to resolve proxy hosts in
included sub-configuration files:

* https://www.nginx.com/blog/dns-service-discovery-nginx-plus/
* https://distinctplace.com/2017/04/19/nginx-resolver-explained/
