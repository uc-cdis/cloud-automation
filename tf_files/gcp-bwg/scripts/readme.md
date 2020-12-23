# Script Helper
A script helper is included. This script must be passed in the organization ID and the seed project name. The seed project name must be manually created first before running the setup-sa script, or else it will fail. The script will check and confirm the project exists before continuing.

Once the script confirms the Organization ID and the Seed Project are valid, it will create a new bucket called "terraform-bucket-{random numbers}". This bucket is to hold the terraform state files.

After the bucket is created for the state files, it will then create the Seed Service account in the Seed Project, grant the necessary roles to the Seed Service Account, and enable the necessary API's in the Seed Project, create and download the .json credential file for the service account.

Lastly, the script will then create an admin vm as well as rename the .json file and move to the terraform-state bucket.

## Installation Process
Recommended install process is to launch GCP CloudShell and run from within CloudShell.
Run as follows:
```sh
./setup-sa.sh <ORGANIZATION_ID> <SEED_PROJECT_NAME>
```
## Issues
Some issues have been seen with the format of the text file. Use VIM to edit the file type in the following command below:
```sh
:set ff=unix
```
Add save the changes.

## Add Commons SA to CSOC
Run the provided script to add the service account from Commons into the CSOC. This account needs to be added to the CSOC so it can read from the different Terraform State buckets and create VPC peering between commons and the csoc.

The permissions added to the SEED_PROJECT_NAME_CSOC are storage object viewer and creator. These are needed to read in the Terraform state and to create the lock file.

The permissions added to the PROJECT_NAME_CSOC are storage legacy writer. This is needed to add in the Log Writer service account to the bucket.
The permission added to the PROJECT_NAME_CSOC is Compute Network Admin. This is to allow the account to create a VPC peer betweenc commons and csoc.

```sh
./add-commonSA-csoc.sh <serviceAccount@commons.com> <SEED_PROJECT_NAME_CSOC> <PROJECT_NAME_CSOC>
```