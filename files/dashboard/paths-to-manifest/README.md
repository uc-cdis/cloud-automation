# TL;DR 

The paths-to-manifest webapp converts a list of S3 paths pasted into a text area to a gen3-client manifest using a lookup table precomputed from indexd.

## Dev-test

* launch a local web server

```
cd ${GEN3_HOME} && npm install  # if necessary
node gen3/lib/nodejs/httpd/server.js / files/dashboard/paths-to-manifest/src
```

or

```
(cd ${GEN3_HOME}/files/dashboard/paths-to-manifest/src && python3 -m http.server)
```

* connect to http://localhost:3380/index.html or (if using the python server) http://localhost:3380/index.html 

## Generating data/

The app loads an S3 path to `did` mapping from `data/icgc.json`

```
cd ${GEN3_HOME}/files/dashboard/paths-to-manifest/src
gen3 api indexd-download-all icgc.bionimbus.org ./data
cd data
for name in index*.json; do 
  echo $name; 
  jq -r .records[] < $name >> records.json; 
done
jq -s -r '. | map({did:.did, url:.urls[0]})' < records.json > icgc.json
```

## Deploy

We deploy the reports webapp to a commons by copying the code
to the `/dashboard/` area of the commons' manifest folder,
then running `gen3 dashboard gitops-sync`:

* update the manifest, and merge the pr
```
rsync -av ${GEN3_HOME}/files/dashboard/paths-to-manifest/src/ cdis-manifest/my.commons/dashboard/Public/paths-to-manifest/
```
* on the admin vm:
```
(cd cdis-manifest && git pull && gen3 dashboard gitops-sync)
```

* access the webapp at https://my.commons/dashboard/Public/paths-to-manifest/index.html
