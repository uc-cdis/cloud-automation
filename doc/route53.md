# TL;DR

Helpers for registering k8s load balancers with route53 DNS

## Use

### skeleton

Scans the active k8s cluster for public load balancers, and
generates json that can be passed to `aws route53 change-resource-record-sets`
to update route53.

```
  gen3 route53 skeleton | tee dnsData.json
```

Note: be sure to validate the contents of dnsData.json -
especially change the default `Name` values - which are
just `$namespace.planx-pla.net`

### apply

Apply the `data.json` commands from `gen3 route53 skeleton` to
the specified route53 zone.

Note: the hosted-zone-id's are available via:
```
  aws route53 list-hosted-zones
```

Ex:
```
  gen3 route53 apply hosted-zone-id dnsData.json
```

Note: check the status of a submitted DNS change with `aws route53 get-change` - ex:
```
aws route53 get-change --id /change/C1W7NBLDVFMRI4
```
