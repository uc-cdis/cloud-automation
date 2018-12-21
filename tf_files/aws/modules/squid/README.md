# Description
Squid proxy in the CSOC account is going to be used by the admin VMs in CSOC to talk to the outside world.

#Requirement
Our requirement is that the outbound traffic from adminVM in CSOC is only allowed to CSOC-VPC CIDR, associated child account VPC CIDRs and  AWS cloudwatch CIDR. All the internet traffic for the admin VMs will be routed through the squid proxy in CSOC.

