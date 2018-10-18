# TL;DR

Backup the local `~/$vpc_name` folder to the S3 bucket referenced by the $s3_bucket environment variable.
This usually runs as part of an initial commons setup.
The need for this decreases as more of our configuration moves into gitops.
