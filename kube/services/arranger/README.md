# TL;DR

The arranger deployment provides a graphQL API endpoint that
interacts with gen3 elastic search indexes in a way defined
by an "arranger project" configuration saved in its own 
elastic search indexes.

## Arranger Project

Gen3 uses the [arranger project](https://github.com/overture-stack/arranger) 
to implement graphQL access to ES (elastic search) indexes generated form
the graphdb by an ETL process.  The [gen3 arranger server](https://github.com/uc-cdis/gen3-arranger) publishes the graphQL endpoint for a single arranger project
with arborist middlware for authz.

## Arranger Development

Arranger deployment is a muiltistep process.  Develop and test the ETL and arranger configuration in a QA environment, then publish the tested configuration to production.

* First - save an `etlMapping.yaml` to the gitops repo that configures the graphdb to ES ETL.
* Next - run the ETL.  As a best practice generate versioned data indexes (`niad_v1`, `niad_v2`, ...), then alias the active index:
```
gen3 es port-forward
gen3 es alias niad_v1 niaid
```
* Next - use the [arranger dashboard](../arranger-dashboard/README.md) to generate an arranger project configuration.
* Update the arranger configuration in gitops `manifest.json` to use the specified arranger project, and deploy arranger:
```
$ cat cdis-manifest/qa-brain.planx-pla.net/manifest.json
 ...
 "arranger": {
    "project_id": "brain",
    "auth_filter_field": "auth_resource_path",
    "auth_filter_node_type": "case"
  },
  ...
  ```
  * Configure the data-portal's exploration page to work with the deployed arranger project
  
## Production Deployment

* Push the ETL mapping and manifest.json configurations to gitops
* Run the ETL in production, and setup an index alias with the name expected by the arranger project
* Copy the arranger project configuration from QA to production
    - In QA
```
$ gen3 es port-forward
$ gen3 es export destFolder arrangerProjectName
$ copy destFolder to cdis-manifest (or gitops repo) as arrangerProjects/arrangerProjectName folder, and submit PR
```

  - In Prod
```
$ cd cdis-manifest/hostname (or gitops folder)
$ git pull
$ gen3 es port-forward
$ gen3 es import sourceFolder arrangerProjectName
  # where sourceFolder should be the arrangerProjects/arrangerProjectName folder copied from QA 
```
* Finally - deploy the arranger server and data portal
