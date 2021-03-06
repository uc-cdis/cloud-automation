# TL;DR

Helpers for interacting with the gen3 api

## Use

### indexd-delete

Delete a record out of indexd using basic-auth creds:

```
  gen3 api indexd-delete $did
```

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
  gen3 api access-token [user-email] [expires-in (default: 3600)] [skip-cache (default: false)]
```

### api-key

Generate a new api key for a given user or service account.

```
gen3 api api-key <username>
```

List old api keys with curl:
```
gen3 api curl credentials/cdis/ <username>
```

Delete an old api key with curl:
```
gen3 api curl credentials/cdis/<kid> <username> DELETE
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

### hostname

Shortcut for `g3kubectl get configmap global -o json | jq -r .data.hostname`

ex:
```
  gen3 api hostname
```

### environment

Shortcut for `g3kubectl get configmap global -o json | jq -r .data.environment`

ex:
```
  gen3 api environment
```

### namespace

Alias for `gen3 db namespace` - echo kubectl namespace best guess

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

Curl the endpoint of the given commons with the user's access token, POST jsonFile if given, DELETE if method specified

```
  gen3 api curl path user-email jsonFile
```
or
```
  gen3 api curl path path/to/apikey.json jsonFile
```
or
```
  gen3 api curl path path/to/apikey.json DELETE
```

ex:
```
  gen3 api curl /user/user reubenonrye@uchicago.edu
```

### sower-run

Submit the given command file to sower to launch a job,
then wait for the job to finish, and fetch the job output.
Note - see `sower-template` below for help generating a
sower command file.

* run on an admin vm with a user name - fetches an access-token for that user from fence
```  
  gen3 api sower-run commandFile.json user-email
```

* run on any machine with an api key
```
  gen3 api sower-run commandFile.json path/to/apikey.json
```

### safe-name

Generate a name that is safe from collisions across environments and namespaces and is less than 64 characters from the given base name - envname--namespace--basename.  If no base name is given, then a random base is generated.

ex:
```
gen3 api safe-name myName
```

### sower-template

Generate a skeleton for a sower job, so it can be used with `gen3 api sower-job` or some similar tool.  Currently only supports the following job types:

* pfb
```
$ gen3 api sower-template pfb | tee commandFile.json
{
  "action": "export",
  "input": {
    "filter": {
      "AND": []
    }
  }
}
```
