# TL;DR 

how to test the reports webapp with the local sample data

## Dev-test

* launch a local web server

```
cd ${GEN3_HOME} && npm install  # if necessary
node gen3/lib/nodejs/httpd/server.js /2019/10 files/dashboard/usage-reports/sampleData/10 / files/dashboard/usage-reports/src/
```

* connect to http://localhost:3380/index.html
* open the browser dev tools
* set a flag in the browser console, so the webapp will load the sample data

```
sessionStorage.setItem('gen3Now', '1571437338314');
```

* reload and go!

## Deploy

We deploy the reports webapp to a commons by copying the code
to the `/dashboard/` area of the commons' manifest folder,
then running `gen3 dashboard gitops-sync`:

* update the manifest, and merge the pr
```
rsync -av ${GEN3_HOME}/files/dashboard/usage-reports/src/ cdis-manifest/my.commons/dashboard/Secure/reports/
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
