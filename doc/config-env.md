# TL;DR

Copies environment configuration from specified `source` environment to specified `target` environment then stands up the services in the configuration file.


## Use
This tool can be used in two ways. 
- To copy a production environment or qa environment into your development environment
Specify the name of the Github repo and the name of the environment you wish to copy <br />
`gen3 config-env copy cdis-manifest gen3.biodatacatalyst.nhlbi.nih.gov` <br />

  - Copies the entire set of configuration artifacts from a source environment (e.g. `gen3.biodatacatalyst.nhlbi.nih.gov`) into your environment e.g. pauline.planx-pla.net (keeping the environment-specific settings, e.g., hostname, vpc, k8s namespace, guppy ES index, etc.)


- To deploy a version to a target environment
Specify the version you wish to apply to the services. <br />
`gen3 config-env apply 2020.09` <br />
  - Applies a given version to all services declared in the environment's manifest
Optionally, a json-formatted string can be used to specify specific versions for certain services. <br />

  `gen3 config-env apply 2020.09 {"ambassador":"quay.io/datawire/ambassador:2020.10"}` <br />
  - Applies a given version to all services declared in the environment's manifest except for services defined in the optional json argument

