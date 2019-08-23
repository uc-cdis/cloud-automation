# TL;DR

This folder holds kubernetes deployment and service resources for [Guppy](https://github.com/uc-cdis/guppy).
Configure and launch Guppy with `gen3 kube-setup-guppy`.

## Guppy configuration
### Basic configuration

Before launch, we need to write config and tell Guppy which elasticsearch indices and which auth control field to use. 
Please add following block into your `manifest.json`: 

```
"guppy": {
  "indices": [
    {
      "index": "${ES_INDEX_1}",
      "type": "${ES_DOC_TYPE_1}"
    },
    {
      "index": "${ES_INDEX_2}",
      "type": "${ES_DOC_TYPE_2}"
    },
    ...
  ],
  "config_index": "${ES_ARRAY_CONFIG}", // optional, if there's array field, Guppy read the configs from this index.
  "auth_filter_field": "${AUTH_FILTER_FIELD}",
},
```


For example as below: 
```
"guppy": {
  "indices": [
    {
      "index": "gen3-dev-subject",
      "type": "subject"
    },
    {
      "index": "gen3-dev-file",
      "type": "file"
    }
  ],
  "configIndex": "gen3-dev-config",
  "auth_filter_field": "gen3_resource_path"
},
```

### Tier access customization
Guppy also imports configuration for the commons' manifest. The optional `tier_access_level` property in the `global` object of `manifest.json` determines the access level of a common and thus affects the behavior of Guppy. Valid options for `tier_access_level` are `libre`, `regular` and `private`. Common will be treated as `private` by default.

For `regular` level data commons, there's another configuration environment variable `tier_access_limit`, which is the minimum visible count for aggregation results. By default set to 1000. 
