# TL;DR

Terraform module that creates an S3 logs bucket:

* a single private S3 bucket with encryption enabled
and a lifecycle policy that erases the data after 120 days.
