## TL;DR

External facing services are accessed through this reverse proxy at 
different URL paths under the same domain.

### Run reverse proxy

- Create a cert in AWS Certificate Manager, and register it in the global config map.  This will require the admin for the domain approve it through email
- `gen3 kube-setup-revproxy`

Note that `kube-setup-revproxy` accpets an options `--dryrun` flag that prevents it from deploying the public `revproxy-service-elb.yaml` load balancer - instead it just echos the yaml to the screen, so that we can verify that the template is being processed as expected
- update DNS to point to your ELB

### How it works

`kube-setup-reverse-proxy` does the following:
* register each files under `revproxy/gen3.nginx.conf` that corresponds with a currently running kubernetes service with the `revproxy-nginx-subconf` configmap; the `revproxy` pod mounts the configmap to `/etc/nginx/gen3.conf/`
* register `00nginx-config.yaml` as the core `revproxy-nginx-conf` configmap - which the `revproxy` pod mounts as `nginx.conf` which in turns `includes` the service files at `/etc/nginx/gen3.conf/*.conf` 

### Nginx resolver

We leverage the nginx DNS resolver to resolve proxy hosts in
included sub-configuration files:

* https://www.nginx.com/blog/dns-service-discovery-nginx-plus/
* https://distinctplace.com/2017/04/19/nginx-resolver-explained/
