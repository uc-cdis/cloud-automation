# TL;DR

Script to verify bucket-manifests.

## Overview

We need to verify various things during deployments of new code and data. This script should aid in the verification of those processes.

## Use

### gen3 verify bucket-manifest

```
ex:
gen3 verify bucket-manifest <bucket name> <s3/gs> <aws profile/gcp project>
```
