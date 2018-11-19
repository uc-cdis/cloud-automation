# TL;DR

Reset Gen3 objects/services in namespace. This includes deleting all deployments 
and dropping all databases, before recreating databases and deployments.
The script will prompt you to accept dropping each database.

## Example

* `gen3 reset`

## Example of workflow for switching dictionary

1. Update manifest with new dictionary URL, and merge change to master branch
2. Run `gen3 reset`
3. Create a program and project, either through Windmill or directly through the API
4. Populate databasses, either by submitting data through Windmill or running the data-generator
from [this Github repo](https://github.com/occ-data/data-simulator) using the `GenTestDataCmd.R` script. Refer to the documentation for this Github repo for more information