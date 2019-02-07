# TL;DR

Helper uploads a folder of json indexd records.

## Use

```
  gen3 indexd-post-folder [folder]
```

Post the .json files under the given folder to indexd
in the current environment: $DEST_DOMAIN

Note - currently only works with new records - does not
attempt to update existing records.

A new record looks like this:

```
 {
    "acl": [ "*" // public access - otherwise list of project accessors
    ],
    //"did": "",
    //"file_name": "",
    "form": "object",
    "hashes": {
      //"md5": "c1898b7f2865ef7d7847b40e58f7c49c"
    },
    "metadata": {},
    "size": 0,
    "urls": [
      //"s3://tcga-protected-dcf-databucket-gen3/testdata"
    ],
    "urls_metadata": {
      //"s3://tcga-protected-dcf-databucket-gen3/testdata": {
      //"acls": "test"
      //}
    }
```
