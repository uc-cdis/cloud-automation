# TL;DR

Wrappers for some AWS cli commands for EC2
Most often used to reboot a misbehaving worker node in AWS.

## Use

### filters

Some commands accept optional filters for selecting specific instances.

* `--owner-id <aws account id>`
* `--private-ip <instance private ip>`
* `--instance-id <id of instance>`
* `<instance private ip>` - same as --private-ip by default

The `gen3 ec2 filter $filters` command translates the above
flags into the `--filter` arguments suitable to pass to 
`aws ec2 describe-instances` (see `gen3 ec2 describe` below).

### asg-describe "default"|"jupyter"

Retrieve the json description of the "default" or "jupyter" node pool.
You can distinguish between cluster nodes in the kubernetes cluster
with the `role` label

Ex:
```
$ kubectl get nodes -l role=default
$ kubectl get nodes -l role=jupyter

$ gen3 ec2 asg-describe default
```

### asg-set-capacity "default"|"jupyter" $number|+/-$increment

Set the desired capacity for the "default" or "jupyter" autoscaling group.
If the number argument is preceded by "+" or "-", then increment or decrement
the current desired capacity without violation the group max or min.

Ex:
```
$ gen3 ec2 asg-set-capacity jupyter +3
```

### describe

Retrieve all info about instances
```
gen3 ec2 describe $filters
```
Options:
- filters: optional filters as described above

### instance-id
```
gen3 ec2 instance-id $filters
```
Options
- filters: filters as described above

### public-ip
```
gen3 ec2 public-ip $filters
```
Options
- filters: optional filters as described above

### reboot
```
gen3 ec2 reboot $filter
```


### stop
Stop an instance

```
gen3 ec2 stop $filter
```


### snapshot

Snapshot the root drive of an ebs disk
```
gen3 ec2 snapshot $filters
```

### terminate
Terminates an EC2 instance
```
gen3 ec2 terminate [-y] [--dry-run | -d] $filters
```
Options:
- filters
- -y: if present, it will terminate without requesting confirmation from the user
- -d | --dry-run: will do a dry run of termiantion (ie won't actually delete it)

