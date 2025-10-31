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

### `gen3 es garbage`

list the ES indices that can be garbage collected
* select indices not referenced by an alias ignoring time_ aliases
* select indices that look like an ETL index: NAME_NUMBER
* group the remaining NAME_NUMBER indices by NAME, and remove the largest NUMBER index from each group
* return the remaining indices

### `gen3 es indices`

list the elastic search indices
  
### `gen3 es mapping index-name`

fetch the type-mapping for the given index

### `gen3 es port-forward`

forward the es-proxy to localhost, and `export ESHOST`

### `gen3 es create $indexName mappingFile.json`

create a new ES index with the given type mappings

Sample mapping file:
```
{
    "mappings" : {
      "_doc" : {
        "properties" : {
          "array" : {
            "type" : "keyword"
          },
          "timestamp" : {
            "type" : "date"
          }
        }
      }
    }
}
```

Also see the [jenkins setup scripts](https://github.com/uc-cdis/gen3-qa/blob/master/suites/guppy/jenkinsSetup/jenkinsSetup.sh) in the gen3-qa repo.

### `gen3 es health`

Hit the `_cluster/health` endpoint.
