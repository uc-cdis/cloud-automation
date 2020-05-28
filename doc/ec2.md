# TL;DR
Wrappers for some AWS cli commands for EC2
Most often used to reboot a misbehaving worker node in AWS.

## Use

### Filters
Some commands accept optional filters for selecting specific instances.
* `--owner-id <aws account id>`
* `--private-ip <instance private ip>`
* `--instance-id <id of instance>`

### describe
Retrieve all info about instances
```
gen3 ec2 describe (zero or more filters)
```
Options:
- filters: optional filters as described above

### public-ip
```
gen3 ec2 public-ip (zero or more filters)
```
Options
- filters: optional filters as described above

### reboot
```
gen3 ec2 reboot <node.ip.address>
```
Options:
- node.ip.address: node ip address (private ip)

### snapshot

Snapshot the root drive of an ebs disk
```
gen3 ec2 snapshot (zero or more filters)
```

### terminate
Terminates an EC2 instance
```
gen3 ec2 terminate <instance id> [-y] [--dry-run | -d]
```
Options:
- instance id: id of instance to terminate
- -y: if present, it will terminate without requesting confirmation from the user
- -d | --dry-run: will do a dry run of termiantion (ie won't actually delete it)

