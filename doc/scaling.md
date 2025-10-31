# TL;DR

Apply the scaling parameters specified in the manifest to the
various gen3 services.

## Manifest config

The scaling group in `manifest.json` specifies
scaling rules for each gen3 service.  The following types of rules are supported:

* `manual` - let the operator manage the service scaling
* `pin` - specify a number of pods for the service
* `auto` - deploy the horizontal-pod autoscaler for the service

If no rule is explicitely
specified, then a default `manual` rule is assumed.

Ex:
```
"scaling": {
  "fence": {
    "strategy": "auto",
    "min": 2,
    "max": 6
  },
  "indexd": {
    "strategy": "auto",
    "min": 2,
    "max": 6
  },
  "revproxy": {
    "strategy": "auto",
    "min": 2,
    "max": 6
  },
  "sheepdog": {
    "strategy": "pin",
    "num": 4 
  }

}
```

## Use

### gen3 scaling rules

Just output the scaling rules currently loaded into the `manifest-scaling` configmap.
Note - use `gen3 gitops configmaps` to load all the manifest configmaps from the local `cdis-manifest/` folder.

### gen3 scaling apply all

Delete existing horizontal pod autoscales, then apply the scaling rules (see `gen3 scaling rules` above) to the services currently running on the cluster.  Ignores rules for services without and active deployment.  Will attempt to remove horizontal autoscalers that are no longer required by the scaling rules.

### gen3 scaling apply rule '{rule json}'

Apply a scaling rule of form
```
{
  "key": "service name",
  "value": {
    "strategy": "pin|manual|auto",
    ...
  }
}
```

Ex:
```
gen3 scaling apply rule '{ "key": "fence", "value": { "strategy": "pin", "num": 2 }}'
```

### gen3 scaling replicas serviceName count

Set the replicas on the given service's deployment to the specified count.


### gen3 scaling update deploymentName min max (optional targetCpu)

Update horizontal pod autoscaling rules on the fly. 

Ex:
```
gen3 scaling update fence 1 2 50
```
