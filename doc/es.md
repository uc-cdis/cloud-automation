# TL;DR

Elastic search helper.
On AWS the first step is to run `gen3 es port-forward` that forwards
a connection to the `aws-es-proxy` pod, and sets up the `ESHOST`
environment variable.

## Use

```
gen3 es 
  alias [index-name] [alias-name]
    (re)create an alias for the given index if alias-name is given - 
    otherwise just lists the aliases associated with the given index
  delete index-name[/type/document-id]
    delete and index or document
  dump index-name
    dump the contents of an ES index (ex: arranger-projects)
  export destFolder project-name
  import srcFolder project-name
  indices
    list the elastic search indices
  mapping index-name
    fetch the type-mapping for the given index
  port-forward
    forward the es-proxy to localhost
```


