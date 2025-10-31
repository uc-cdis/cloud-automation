# TL; DR

Terraform modules for GCP infrastructure.

The `gcp/*` folders configure the GCP terraform provider and
reference terraform modules under `gcp/modules/` to provision
different types of Gen3 infrastructure.

# Gen3 configuration

The `gen3` scripts require that we name a profile corresponding to a GCP
project with a `gcp-` prefix, so:
`gen3 workon gcp-{PROFILE} name_{TYPE}`, where `PROFILE` corresponds
to the name of a [cloudsdk configuration](https://cloud.google.com/sdk/docs/configurations).
The `workon` tool sets the `CLOUDSDK_ACTIVE_CONFIG_NAME` environment
variable to enable the credentials registered with that `gcloud` configuration.  
Save service account keys for different configurations under the `$(gen3_secrets_folder)/gcp/` folder:
https://www.terraform.io/docs/providers/google/index.html#authentication-json-file - ex:

```
$ cd "$(gen3_scecrets_folder)"
$ ls gcp/
gcp-cdistest.json
```

# Links

https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters
