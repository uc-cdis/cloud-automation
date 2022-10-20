# TL;DR

Terraform module that creates:

* a single private S3 bucket with encryption enabled
* a policy that can read from that bucket
* a policy that can read from and write to that bucket
* a read role
* a read+write role
* a read instance-profile
* a read+write instance profile

