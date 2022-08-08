# Terraform Migration Steps

The following guide is intended to guide you through the process of bringing up a gen3 commons. This particular guide is intended for those who would build commons independently from a centralized account. Said account will be called CSOC and is used to control multiple commons and also collect logs from them for later processing. 

The following guide is intended to guide you through the process of migrating terraform from 0.11/0.12 to our tf > 1.0 version. The newer terrafrom includes a number of newer features and our old modules will be deprecated eventually.

# Table of contents

- [1. Requirements](#requirements)
- [2. Initial Setup](#initial-setup)
- [3. Running the Change](#running-the-change)
- [4. Post Command Steps](#post-command-steps)
- [5. Verification of Migration](#verification-of-migration)

## Requirements

To get started you will need to gather your old commons workspace and profile, used in the gen3 workon command. You will need this to feed to the command so that it can pull the necessary terraform state files for migrating existing resources into the new module. If you don't have a commons you can get started with terraform >1.0 by just adding the necessary environment variable describe in the initial setup. You will also need the most up to date cloud-automation because it includes the scripts and updated terraform necessary to run and migrate resources to terraform >1.0.

## Initial Setup

To start you will need to add the following environment variable to your .bashrc file.

```bash
export USE_TF_1="True"
```

Once that is added you will need to logout/login to the user, so that the environment variable takes effect and the gen3setup points to the new terraform folders.

## Running the Change

Once you have it ready you will need to find the necessary profile and workspaces. To find them you can run gen3 ls, which will list the workspaces and profiles used for them. Currently the script expects your commons workspace to have the same identifier as the eks and elasticsearch modules, only including the _eks and _es postfixes for those modules. If the identifiers do not match either reach out to Edward Malinowski on slack or create the workspace by running gen3 workon for the new workspaces, then copying over the terrafrom state file in the s3 bucket from the old workspace to the new one. Once you have everything ready run the following.

```bash
gen3 tf-migrate --old-workspace <old workspace name> --new-workspace <the new workspace that will use tf > 1.0> --profile <the profile used for the old workspace> --migrate-es <optional - use if you want to migrate elasticsearch, do not set if you did not deploy elasticsearch>
```

This will will copy down the commons, EKS and ES terrafrom state files, then merge them and push them up to the new workspace. After that it will move resources to be compatible with the new modules.

## Post Command Steps

After the command finishes it should output a list of commands to run to import new resources. You will need to first get a working config.tfvars file though, so you should go into each of the workspaces you migrated, copy their config.tfvars files and merge them. There will likely be some duplicates between the files, so ensure you delete any duplicate lines, such as vpc name, so that the terraform can run. We also started deprecated the naming of gdcapi, as sheepdog is our newer naming convention, so you should update variables containing gdcapi to contain sheepdog instead. From there you can workon your new workspace and run a gen3 tfplan to ensure it will create a plan without errors. If you can create a plan run the import commands at this point and run another plan.

## Verification of Migration

At this point all of the resources should be migrated. There may be some smaller changes that happen as a result of our merging of modules and standardizing variables as well as standard commons updates. Look out for things like organization name tag changes as well as things like updating the launch configuration for the autoscaling groups etc. However, if you notice a big change like destroying a database or EKS cluster, do not run the change and instead reach out to Edward Malinowski on slack for troubleshooting. If all looks good though, run a gen3 tfapply and your migration to tf >1.0 should be completed. From this point on you should use this new workspace for all future terraform changes, as it will use our newer modules which will be the only ones updated moving forward.
