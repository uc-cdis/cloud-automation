# TL;DR

Helper to manipulate the routing table for commons kubernetes workers

## Use

### skip-proxy

Would add a CIDR to the routing table associated with the kubernetes workers to skip the proxy.

Basically, the CIDR provided  will go through the NAT gateway associated with vpc. 
Something equivalen to 
`aws ec2 create-route --route-table-id <RT-ID> --destination-cidr-block <CIDR> --nat-gateway-id <NAT-ID>`
is ran under the hood.


```
  gen3 routing skip-proxy 128.135.0.0/16
```

Note: be sure to provide a valid CIDR.

