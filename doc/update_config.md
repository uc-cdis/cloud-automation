# TL;DR

Little helper for updating configmaps from files.
Deletes the specified configmap if it already exists, then
creates the configmap from the given file.

## Use

```
gen3 update_config configMapName filePath
```

## Example

* `gen3 update_config fence ./api_configs/user.yaml`
