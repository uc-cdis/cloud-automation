# TL;DR

Used to get download metrics

## Overview

We have requests for downloads in our logs. We can get metrics from them
by scraping the logs.

## Use

### gen3 download-metrics

Command to get the download metrics. Required variable is --vpc. The optional variables are the following:

* bucket-name: Used to filter out entries from a specific bucket
* bucket-type: Used with bucket name. Specifies the type of bucket it is, s3, gs
* preserve-usernames: Whether or not to include usernames in the metrics
* publish-dashboard: Will publish to dashboard after complete if flag set

``` bash
ex:
gen3 download-metrics --vpc=devplanetv1 --bucket=name=test --preserve-usernames=True --publish-dashboard=True
```
