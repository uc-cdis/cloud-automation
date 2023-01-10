## TL;DR

External facing services are accessed through this reverse proxy at
different URL paths under the same domain.

### Run reverse proxy in AWS

The `revproxy-service-elb` k8s LoadBalancer service manifests itself
as an AWS ELB that terminates HTTPS requests (using an AWS Certificate Manager supplied certificate configured in the service's yaml file), and
forwards http and https traffic to the
revproxy deployment using http proxy protocol.

Update: The revproxy-service-elb and WAF is now only applied if you set/add the "waf_enabled" flag to true in the manifest-global configmap (set via the global section of the manifest.json). We now recommend using the ALB Ingress via the kube-setup-ingress script detailed here: https://github.com/uc-cdis/cloud-automation/blob/master/doc/kube-setup-ingress.md

- Create a cert in AWS Certificate Manager, and register it in the global config map.  This will require the admin for the domain approve it through email
- `gen3 kube-setup-revproxy` - deploys the service - creating an AWS ELB
- update DNS to point at the ELB

The `gen3 kube-setup-revproxy` script sets up 2 k8s services:

  * `revproxy-service` - legacy service - now available for internal clients
         that want to route
         through the revproxy rather than access a service directly for some reason
  * `revproxy-service-elb` - public facing load balancer service that
        target the `revproxy-deployment` backend in different ways depending
        on which environment gen3 is deployed to (AWS, GCP, onprem, ...)

The `revproxy-service-elb` service came about when we decided we wanted to change the service configuration in a way that would require the existing service to be re-created - which would change its DNS in AWS, and require downtime while we switch DNS to the new ELB.

Note that `kube-setup-revproxy` accepts an optional `--dryrun` flag that prevents it from deploying the public `revproxy-service-elb.yaml` load balancer - instead it just echos the yaml to the screen, so that we can verify that the template is being processed as expected


### Run reverse proxy outside AWS

We currently do this hacky thing where we toggle between different configurations
based on the value of the 'revproxy_arn' field of the global configmap

* In GCP we terminate SSL traffic on the revproxy-deployment.  If the global configmap `revproxy_arn` is set to GCP, then `kube-setup-revproxy` configures the `revproxy-service-elb` to transparently forward https and http traffic, so that:
    - incoming https traffic is forwarded to the revproxy-deployment's https listener on port 443
    - incoming http traffic is forwarded to the revproxy-deployment's http listener on port 83 that HTTP-redirects all requests to https

* On prem we terminate SSL traffic on an external proxy (either nginx or F5).  If the global configmap `revproxy_arn` is set to ONPREM, then `kube-setup-revproxy` configures the `revproxy-service-elb` to forward incoming https and http requests as http to the revproxy-deployment backend, so that:
    - incoming https traffic is forwarded to the revproxy-deployment's http listener on port 80
    - incoming http traffic is forwarded to the revproxy-deployment's http listener on port 83 that HTTP-redirects all requests to https

Note: also see the comments in [gen3/bin/kube-setup-revproxy](https://github.com/uc-cdis/cloud-automation/blob/master/gen3/bin/kube-setup-revproxy.sh)

### How it works

`kube-setup-reverse-proxy` does the following:
* register each files under `revproxy/gen3.nginx.conf` that corresponds with a currently running kubernetes service with the `revproxy-nginx-subconf` configmap; the `revproxy` pod mounts the configmap to `/etc/nginx/gen3.conf/`
* register `nginx.conf` as the core `revproxy-nginx-conf` configmap - which the `revproxy` pod mounts, which in turns `includes` the service files at `/etc/nginx/gen3.conf/*.conf`

### Nginx resolver

We leverage the nginx DNS resolver to resolve proxy hosts in
included sub-configuration files:

* https://www.nginx.com/blog/dns-service-discovery-nginx-plus/
* https://distinctplace.com/2017/04/19/nginx-resolver-explained/

### Canary services

The reverse proxy manages canary releases. See here for information on canary rollouts:
* https://martinfowler.com/bliki/CanaryRelease.html

Canary service deployment branches are defined in the manifest just like regular services. The probability of a client being directed to a canary deployment of a service is also defined in the manifest under the `canary` section - a weight of 0 means zero percent traffic is sent to the canary, whereas a weight of 100 means 100% of traffic is sent to the canary deployment.

When determining which release to direct a client to, the revproxy goes through the following steps:

1. Get the `service_releases` cookie from the request. If it doesn't exist, we will create a new one.
2. For each service defined to have a canary release (defined in an array in the helpers.js file):
  * if its release is already defined in the cookie, continue (ie use that release)
  * if its release is not in the cookie, hash the request info into an integer between 0 and 99; if the value is less than the manifest defined weight, set the service to canary in the cookie, else set to production
3. Add a header to set the cookie to the updated version
4. Direct client to production or canary depending on the value in the cookie

### Modsecurity

The [modsecurity](https://modsecurity.org) web application firewall
support in recent [cdis nginx](https://github.com/uc-cdis/docker-nginx) load configuration rules via the `manifest-modsec` configmap.  The default [OWASP](https://www.modsecurity.org/crs/) based rules are in `cloud-automation/gen3/lib/manifestDefaults/modsec/`.  [This document (waf.md)](../../../doc/waf.md) has more details.

### Workspace Parent Deployment

When the manifests `global.portal_app` property is set to `GEN3-WORKSPACE-PARENT`, then `kube-setup-revproxy` assumes that we are deploying a multi-account workspace parent rather than a traditional Gen3 commons.  In this mode the reverse proxy deploys the `portal-workspace-parent` nginx configuration with different rules than the normal portal configuration.
* redirects unmapped traffic to `/dashboard/Public/index.html` - a custom webapp - possibly based on the code in [cloud-automation/files/dashboard/workspace-public/](../../../files/dashboard/workspace-public/)
* a `/workspace-authorize/` endpoint that redirects clients to a subdomain's `/wts/oath2/authorize` endpoint where the subdomain is identified from the state query parameter

### Other stuff

Too lazy to document this stuff.

* CSRF check
* user token parsing
* arborist auth integration
* [IP blacklist](../../../gen3/lib/manifestDefaults/revproxy/)
* [maintenance mode](../../../doc/maintenance.md)
* [gen3 kube-setup-revproxy](../../../doc/kube-setup-revproxy.md)
