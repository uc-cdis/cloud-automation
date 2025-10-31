# TL;DR

Templates for deploying `gen3` services to a kubernetes cluster.


## Template processing

Both `gen3 roll ...` and `gen3 runjob ...` merge `kube/.../..yaml` templates with data
from the [cdis-manifest](https://github.com/uc-cdis/cdis-manifest) and
variables supplied on the command line.  The flow is:
```
raw.yaml >>> template processing >>> kubectl
```

For example, this is the `manifest.json` file for the `reuben.planx-pla.net` commons:
```
{
  "notes": [
    "This is the dev environment manifest",
    "That's all I have to say"
  ],
  "jenkins": {
    "autodeploy": "yes"
  },
  "versions": {
    "arranger": "quay.io/cdis/arranger:master",
    "fence": "quay.io/cdis/fence:master",
    "indexd": "quay.io/cdis/indexd:master",
    "peregrine": "quay.io/cdis/peregrine:master",
    "pidgin": "quay.io/cdis/pidgin:master",
    "sheepdog": "quay.io/cdis/sheepdog:master",
    "portal": "quay.io/cdis/data-portal:master",
    "fluentd": "fluent/fluentd-kubernetes-daemonset:cloudwatch",
    "jupyterhub": "quay.io/occ_data/jupyterhub:master"
  },
  "jupyterhub": {
    "enabled": "no"
  },
  "arranger": {
    "project_id": "dev"
  }
}
```

Template processing of this manifest yields the following key-value replacements:
```
(GEN3_IMAGE_ARRANGER, image: quay.io/cdis/arranger:master)
(GEN3_IMAGE_FENCE, image: quay.io/cdis/fence:master)
(GEN3_IMAGE_INDEXD, image: quay.io/cdis/fence:master)
...
(GEN3_VERSIONS_ARRANGER, quay.io/cdis/arranger:master)
(GEN3_VERSIONS_FENCE, quay.io/cdis/fence:master)
(GEN3_VERSIONS_INDEXD, quay.io/cdis/indexd:master)
...
(GEN3_JUPYTERHUB_ENABLED, no)
(GEN3_ARRANGER_PROJECT_ID, dev)
```

The `gen3 roll arranger` command processes the `arranger-deploy.yaml` template:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: arranger-deployment
spec:
...
    metadata:
      labels:
        app: arranger
        GEN3_DATE_LABEL
      containers:
        - name: arranger
          GEN3_ARRANGER_IMAGE|-image: quay.io/cdis/arranger:master-|
          livenessProbe:
            ...
          env:
          - name: GEN3_ES_ENDPOINT
            value: esproxy-service:9200
          - name: GEN3_ARBORIST_ENDPOINT
            value: http://arborist-service
          - name: GEN3_PROJECT_ID
            value: GEN3_ARRANGER_PROJECT_ID|-dev-|
          volumeMounts:
            - name: "cert-volume"
              readOnly: true
          ...
```
to generate a `yaml` output to send to kubernetes that looks like this:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: arranger-deployment
spec:
...
    metadata:
      labels:
        app: arranger
        date: 1534177684
      containers:
        - name: arranger
          image: quay.io/cdis/arranger:master
          livenessProbe:
            ...
          env:
          - name: GEN3_ES_ENDPOINT
            value: esproxy-service:9200
          - name: GEN3_ARBORIST_ENDPOINT
            value: http://arborist-service
          - name: GEN3_PROJECT_ID
            value: dev
          volumeMounts:
            - name: "cert-volume"
              readOnly: true
          ...
```

A few notes:

* GEN3_DATE_LABEL is a helper that expands to `date: (date +%s)`
* a template can specify a default value to use if a variable is undefined using the syntax: `|-DEFAULT-|`
* `gen3 runjob` accepts key-value pairs on the command line, but the values expand to `value: VALUE`,
so `gen3 runjob gentestdata VAR1 VALUE1` replaces occurrences of `VAR1` in `gentestdata-job.yaml`
with `value: VALUE1`.  A `...-job.yaml` template might look like this:
```
...
    env:
       - name: ENVVAR1
         VAR1
       - name: ENVVAR2
         VAR2
...
```

## Cronjob manifest

To setup cronjobs you need to create a cronjobs folder under the manifests folder for you commons. Under that folder you need to create a cronjobs.json file with your cronjobs and the schedules, similar to the following:

```json
{
  "etl": "@daily",
  "usersync": "20 * * * *"
}
```
