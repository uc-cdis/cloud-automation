# TL;DR

Packer config files for building the AMI's underlying the squid-proxy, k8s-provisioner, and login-node in our AWS commons VPC's.

Moved here from https://github.com/uc-cdis/images

## Pull the SSH keys

There is a script and an accompanying file in the configs subdirectory.  The script is called getkeys.rb, and the file is called gituserlist.  Edit the gituserlist file to contain the names of the users who's keys we want pre-populated in the images.

Run `./getkeys.rb gituserlist`, and inspect the resulting authorized_keys.//timestamp// file.  If it looks right, replace authorized_keys with it, the continue building your images.

## Build ubuntu16 image

The newer 'ubuntu16_*' images are configured to publish public AMI's with names following the pattern *ubuntu16-NAME-1.0.0-TIMESTAMP*.
The terraform code in the uc-cdis/cloud-automation repository looks for those images under the 'cdistest' AWS account using
search filters like this [https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Images:visibility=public-images;search=707767160287/ubuntu*;sort=creationDate](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Images:visibility=public-images;search=707767160287/ubuntu*;sort=creationDate).  The ubuntu16_client.json and ubuntu16_squid.json packer configs similarly find the latest ubuntu16_base.json AMI with a filter like this:
```
    "source_ami_filter": {
        "filters": {
          "virtualization-type": "hvm",
          "name": "ubuntu16-docker-base-1.0.0-*",
          "root-device-type": "ebs"
        },
        "owners": ["707767160287"],
        "most_recent": true
      }
```

So - to build the ubuntu16 images:
1. `cp variables.example.json ~/.creds/packer/cdistest.json` and set the aws secrets in cdistest.json for the cdistest account
2. `packer build --var-file ~/.creds/packer/cdistest.json images/ubuntu16...`

## Build legacy ubunt14 image

1. Download [packer](https://www.packer.io/downloads.html)
2. `cp variables.example.json variables.json`, change the variables with your credentials, source_ami should be left empty.
3. `packer build --var-file variables.json images/base_image.json`
4. Add the ami for the image built in step 2)  to `variables.json`
5. `packer build --var-file variables.json images/client.json`
