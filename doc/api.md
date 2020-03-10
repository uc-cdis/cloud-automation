# TL;DR

Helpers for interacting with the gen3 api

## Use

### indexd-download-all

Helper downloads all the records from indexd to a folder

```
ex:$ gen3 api indexd-download-all domain.commons.io ./destFolder
```

### indexd-post-folder

Helper uploads a folder of json indexd records.

```
  gen3 api indexd-post-folder [folder]
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

### access-token

Allocate a one-hour access-token for the given user, or re-use one from cache if available.
Assumes that a `fence` pod is running in the current environment.

```
  gen3 api access-token [user-email]
```

### new-program

Attempt to create a new program using a default template -
suitable for dev accounts and testing.

```
  gen3 api new-program [program-name] [user-email]
```

Where `user-email` specifies the user to act as (via `gen3 api access-token`)

ex:
```
  gen3 api new-program jnkns reubenonrye@uchicago.edu
```

### new-project

Attempt to create a new project using a default template -
suitable for dev accounts and testing.

```
  gen3 api new-project [program] [project] [user-email]
```

ex:
```
  gen3 api new-project jnkns jenkins reubenonrye@uchicago.edu
```

Where `user-email` specifies the user to act as (via `gen3 api access-token`)

### curl

Curl the endpoint of the given commons with the user's access token - POST jsonFile if given

```
  gen3 api curl path user-email jsonFile
```

ex:
```
  gen3 api curl /user/user reubenonrye@uchicago.edu
```