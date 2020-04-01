# TL;DR 

The links-page webapp queries the dashboard server for a 
list of files under the 

## Dev-test

Unfortunately this app does not lend itself well to 
local testing, since it relies on the dashboard service's 
behavior of listing keys under a requested prefix.

However basic look and feel development can be done locally like this:

* launch a local web server

```
cd ${GEN3_HOME} && npm install  # if necessary
node gen3/lib/nodejs/httpd/server.js / files/dashboard/links-page/src
```

or

```
(cd ${GEN3_HOME}/files/dashboard/links-page/src && python3 -m http.server)
```

* connect to http://localhost:3380/index.html or (if using the python server) http://localhost:3380/index.html 


## Deploy

We deploy the reports webapp to a commons by copying the code
to the `/dashboard/` area of the commons' manifest folder,
then running `gen3 dashboard gitops-sync`:

* update the manifest, and merge the pr
```
rsync -av ${GEN3_HOME}/files/dashboard/links-page/src/ cdis-manifest/my.commons/dashboard/Public/links-page/
```
* on the admin vm:
```
(cd cdis-manifest && git pull && gen3 dashboard gitops-sync)
```

* access the webapp at https://my.commons/dashboard/Public/links-page/index.html
