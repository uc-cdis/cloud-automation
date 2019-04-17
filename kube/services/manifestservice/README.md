# manifestservice
https://github.com/uc-cdis/manifestservice

Microservice that's responsible for creating and retrieving files from a dedicated s3 bucket.
See repo for more information.

## Deployment

Create an IAM user named "manifest_bot" manually first.

Run
```
gen3 kube-setup-manifestservice
gen3 kube-setup-certs
gen3 kube-setup-networkpolicy
gen3 kube-setup-revproxy
```
Or just `gen3 roll all`

Copy aws key pair for the manifest_bot user to `$VPC_FOLDER/g3auto/manifestservice/config.json` then run `gen3 secrets sync; gen3 roll manfiestservice`

TODO:
Will update `kube-setup-manifestservice` after iam automation is added