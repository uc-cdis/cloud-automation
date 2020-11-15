# TL;DR

Demo dashboard page with links for downloading open-access files from the commons.

## Dev/test


* first, if necessary:
```
(
  cd "${GEN3_HOME}" && npm install
)
```

* launch a local web server
```
(  
  cd "${GEN3_HOME}/files/dashboard/open-links"
  node "${GEN3_HOME}/gen3/lib/nodejs/httpd/server.js" / .
)
```

* connect to http://localhost:3380/index.html
* the jasmine test suite runs in the browser at http://localhost:3380/spec/index.html

## Deploy

We deploy the reports webapp to a commons by copying the code
to the `/dashboard/` area of the commons' manifest folder,
then running `gen3 dashboard gitops-sync`:

* update the manifest, and merge the pr
```
(
  myCommons="${myCommons:-"your.commons"}"
  rsync -av ${GEN3_HOME}/files/dashboard/open-links/ cdis-manifest/$myCommons/dashboard/Public/open-links/
)
```
