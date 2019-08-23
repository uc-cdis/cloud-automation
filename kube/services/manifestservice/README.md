# manifestservice
https://github.com/uc-cdis/manifestservice

Microservice that's responsible for creating and retrieving files from a dedicated s3 bucket.
See repo for more information.

## Deployment

Run
```
gen3 kube-setup-manifestservice
gen3 kube-setup-certs
gen3 kube-setup-networkpolicy
gen3 kube-setup-revproxy
```
Or just `gen3 roll all`