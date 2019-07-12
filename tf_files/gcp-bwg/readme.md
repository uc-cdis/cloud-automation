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
