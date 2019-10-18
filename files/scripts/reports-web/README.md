# TL;DR 

how to test the reports webapp with the local sample data

## Instructions

* launch a local web server

```
cd ${GEN3_HOME} && npm install  # if necessary
node gen3/lib/nodejs/httpd/server.js /2019/10 files/scripts/reports-web/sampleData/10 / files/scripts/reports-web/src/
```

* connect to https://localhost:3380/index.html
* open the browser dev tools
* set a flag in the browser console, so the webapp will load the sample data

```
sessionStorage.setItem('gen3Now', '1571437338314');
```

* reload and go!

