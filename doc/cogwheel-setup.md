# First-time Cogwheel setup in Gen3


## Register an InCommon Service Provider

Refer to the Cogwheel README for instructions. You will need to either be
an InCommon Site Admin or be able to bug one.


## Set up g3auto secrets

A number of configuration files must be mounted into the Cogwheel container.
These should go into a `g3auto/cogwheel` directory that you create.

Refer to the Cogwheel README for the list of files (see the `docker run` command,
which has a bunch of `--mount` arguments) and instructions on how to generate
or edit each file. Templates for most of the files are present in the Cogwheel repo.

For a Gen3 setup you do not need the `localhost.crt` and `localhost.key` files.

In `shibboleth2.xml` you must additionally edit the `<Sessions>` element and
specify `handlerURL="/cogwheel/Shibboleth.sso"`.
Find the element and edit so it looks like this:
```
<Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
    checkAddress="false" handlerSSL="false" cookieProps="http"
    redirectLimit="exact" handlerURL="/cogwheel/Shibboleth.sso">
```


## Update manifest

Add a "cogwheel" entry to your "versions" block with the Cogwheel image.


## Set up database

Set up your database the Gen3 way:
```
gen3 db setup cogwheel
```

NOTE: You may end up having your indexd db server be randomly selected for the
new db, and you may find a funny-looking `index_record_g_ace` table sitting in
your new db with some moldy potato chips atop. This is not intended and is
probably some legacy gen3 artefact. Therefore it might be better to look at
your server farm and find your Fence server, and then specify that, e.g.
`gen3 db setup cogwheel server1`. Otherwise just drop the table.

This will put a `dbcreds.json` file into your `g3auto/cogwheel` folder, from
which you can construct a database URL that you then assign to
`SQLALCHEMY_DATABASE_URI` in your `wsgi_settings.py`.


## Set up client for Fence

You should do a `gen3 secrets sync` before doing this to make sure the pod can
find the db creds.

Presumably your Cogwheel will integrate with your Fence. There is a client
creation job that will make a Fence client for you:
```
gen3 job run cogwheel-register-client
```
Your client name will be `fence-client`. The redirect URL will be for Fence's
Cognito callback.

Look in the db (`gen3 psql cogwheel`, `SELECT * FROM clients;`) for
your new client creds and use those with the Cognito IdP in your Fence config.

The `discovery_url` is
`https://you.planx-pla.net/cogwheel/.well-known/oauth-authorization-server`.


## Roll

```
gen3 roll cogwheel
```

## Test

Try to log in.
