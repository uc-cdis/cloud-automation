# TL;DR 

how to test the reports webapp with the local sample data

## Dev-test

* first, if necessary:
```
(
  cd "${GEN3_HOME}" && npm install  # if necessary
)
```

* launch a local web server
```
(
  cd "${GEN3_HOME}/files/dashboard/usage-reports"
  npm install
  npm start
)
```

* connect to http://localhost:3380/index.html?end=2019/10/18
* the jasmine test suite runs in the browser at http://localhost:3380/spec/index.html

## Deploy

We deploy the reports webapp to a commons by copying the code
to the `/dashboard/` area of the commons' manifest folder,
then running `gen3 dashboard gitops-sync`:

* update the manifest, and merge the pr
```
(
  myCommons="${myCommons:-"your.commons"}"
  rsync -av ${GEN3_HOME}/files/dashboard/usage-reports/src/ cdis-manifest/$myCommons/dashboard/Secure/reports/
  rsync -av ${GEN3_HOME}/files/dashboard/usage-reports/node_modules/ cdis-manifest/$myCommons/dashboard/Secure/reports/modules/
)

```
* on the admin vm:
```
(cd cdis-manifest && git pull && gen3 dashboard gitops-sync)
```

* on the admin vm - deploy the cronjob

```
crontab -e
```
see the instructions at `head ${GEN3_HOME}/files/scripts/reports-cronjob.sh`

* access the reports webapp at https://my.commons/dashboard/Secure/reports/index.html
