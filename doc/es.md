# TL;DR

Elastic search helper.
On AWS the first step is to run `gen3 es port-forward` that forwards
a connection to the `aws-es-proxy` pod, and sets up the `ESHOST`
environment variable, so can `curl $ESHOST`

## Use

### `gen3 es alias [index-name] [alias-name]`

(re)create an alias for the given index if alias-name is given - 
otherwise just lists the aliases associated with the given index

### `gen3 es delete index-name[/type/document-id]`

delete and index or document

### `gen3 es dump index-name [size]`
    
dump the contents of an ES index (ex: arranger-projects)
  
### `gen3 es export destFolder project-name`

### `gen3 es import srcFolder project-name`

### `gen3 es indices`

list the elastic search indices
  
### `gen3 es mapping index-name`

fetch the type-mapping for the given index

### `gen3 es port-forward`

forward the es-proxy to localhost, and `export ESHOST`

### `gen3 es create $indexName mappingFile.json

create a new ES index with the given type mappings
