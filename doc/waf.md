# TL;DR

Configuration for the web application firewall (WAF) on the reverse proxy.

## Overview

The gen3 reverse proxy deploys the [modsecurity](https://github.com/SpiderLabs/ModSecurity) 
WAF when running gen3 nginx builds greater than or equal to [quay.io/cdis/nginx:1.17.6-ctds-1.0.1](https://github.com/uc-cdis/docker-nginx).

The modsecurity rule set is saved in the `manifest-modsec` configmap.  If no rules are present under `manifest-folder/manifests/modsec/`, then the `gen3` tools load the default rule set (based on modsecurity's [OWASP rules](https://github.com/SpiderLabs/owasp-modsecurity-crs)) from [cloud-automation/gen3/lib/manifestDefaults/modsec/](../gen3/lib/manifestDefaults/modsec/).

## Testing New Rules

* make sure the test environment is running the latest revproxy: 
```
[[ “$(jq -r .versions.revproxy)” == “quay.io/cdis/nginx:1.17.6-ctds-1.0.1” ]] || echo “Please update revproxy”
```

* install the default rules
```
cp -r cloud-automation/gen3/lib/manifestDefaults/modsec/ cdis-manifest/test-environment/manifests/modsec/
```
* enable rule enforcement if necessary - edit `cdis-manifest/test-environment/manifests/modsec/modsecurity.conf` - comment out the `SecRuleEngine DetectionOnly` line, and uncomment the `SecRuleEngine On` line

* update reverse proxy
```
gen3 kube-setup-revproxy
```
