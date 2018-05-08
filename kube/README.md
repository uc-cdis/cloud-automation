# TL;DR

Templates for deploying `gen3` services to a kubernetes cluster.
The `g3k` helper scripts merge these templates with data
from the [cdis-manifest](https://github.com/uc-cdis/cdis-manifest).
The g3k helpers also automate the creation of missing secrets and configmaps
(if `~/${vpc_name}_output/creds.json` and similar files are present.
These tools are currently only available on the [CSOC adminvm](https://github.com/uc-cdis/cdis-wiki/blob/master/ops/CSOC_Documentation.md) 
associated with a commons.

Use the [gen3](../gen3/README.md) helper to execute PlanX workflows for deploying infrastructure
and managing kubernetes resources.


### Services
#### [fence](https://github.com/uc-cdis/fence)
The authentication and authorization provider.
#### [sheepdog](https://github.com/uc-cdis/sheepdog/)
API for submitting data model that stores the metadata for this cluster.
#### [peregrine](https://github.com/uc-cdis/peregrine/)
API for querying graph data model that stores the metadata for this cluster.
#### [indexd](https://github.com/LabAdvComp/indexd)
ID service that tracks all data blobs in different storage locations
#### [data-portal](https://github.com/uc-cdis/data-portal)
Portal to browse and submit metadata.

