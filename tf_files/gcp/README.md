# TL; DR

Terraform modules for GCP infrastructure.

The `gcp/*` folders configure the GCP terraform provider and 
reference terraform modules under `gcp/modules/` to provision
different types of Gen3 infrastructure.

# Gen3 configuration

The `gen3` scripts require that we name a profile corresponding to a GCP
project with a `gcp-` prefix, so:
`gen3 workon gcp-{PROFILE} name_{TYPE}`

The `gen3` scripts look for a credentials json file that includes the
project and region details for the profile under the `${GEN3_ETC_FOLDER}/gcp/` folder:
https://www.terraform.io/docs/providers/google/index.html#authentication-json-file - ex:

```
$ gen3 cd config
$ ls gcp/
gcp-cdistest.json
```

# Links

https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters
