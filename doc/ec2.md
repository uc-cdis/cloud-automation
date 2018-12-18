# TL;DR

Most often used to reboot a misbehaving worker node in AWS.

## Use

* describe
```
gen3 ec2 describe node.ip.address
```

* reboot
```
gen3 ec2 reboot node.ip.address
```

## Example

* `gen3 ec2_reboot 10.0.0.4`
