# TL;DR

Basic CDIS VPC with public and private subnet, and bastion node, and
a Squid proxy through which all traffic routes:

* public subnet
    - bastion login node
    - proxy node
* private-user subnect
* route53 .internal.io zone
