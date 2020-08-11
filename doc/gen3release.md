# TL;DR

Copies environment configuration from specified `source` environment to specified `target` environment then stands up the services in the configuration file.

## Gen3 Release SDK


## Use
Set up environment variable `GITHUB_TOKEN` <br />
This tool can be used in two ways. 
- To copy a production environment into your development environment
`gen3 gen3release copy -s uc-cdis/cdis-manifest/gen3.biodatacatalyst.nhlbi.nih.gov -e ~/cdis-manifest/pauline.planx-pla.net` <br />
  - When a production environment is the source environment `uc-cdis/cdis-manifest/` must prefix the production environment name. 
  - Copies the entire set of configuration artifacts from a source environment (e.g. `gen3.biodatacatalyst.nhlbi.nih.gov`) to a target environment (e.g. pauline.planx-pla.net) (keeping the environment-specific settings, e.g., hostname, vpc, k8s namespace, guppy ES index, etc.)


- To deploy a version to a target environment
`gen3 gen3release apply -v 2020.09 -e ~/cdis-manifest/pauline.planx-pla.net` <br />
Applies a given version to all services declared in the environment's manifest