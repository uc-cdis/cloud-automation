# TL;DR
Wrappers for some AWS cli commands for EBS

## Use

### Snapshot
Take a snapshot
```
gen3 ebs snapshot <Volume>
```

### Restore
Restore a EBS volume from a snapshot
```
gen3 ebs restore <Snapshot>
```

### List Snapshots
List Snapshots
```
gen3 ebs list-snapshots
```

### List Volumes
List Volumes
Terminates an EC2 instance
```
gen3 ebs list-volumes
```

### Migrate
Migrates volume from one location to another
```
gen3 ebs migrate <Volume> <Zone>
```

### Jupyter Migrate
Migrates all jupyter instances to specified location
```
gen3 ebs jupyter-migrate <Zone> (Optional)<Namespace>
```

### Kubernetes Migrate
Creates k8 config to update volumes to new locations
```
gen3 ebs kubernetes-migrate <Original Volume> <New Volume>
```

