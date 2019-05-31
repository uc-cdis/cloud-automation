########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info

env = "commons001"
project_name = "<project_name_here>"
billing_account = "<billing_account_here>"
credential_file = "<credentials_here>.json"
create_folder = true
set_parent_folder = true
folder = "<folder_name_here>"
region = "us-central1"
organization = "<organization_name_here>"
org_id = "<org_id_here>"
###### Terraform State
state_bucket_name = "<tfstate_bucket_here>"
prefix_org_policies = "org_policies_commons001"
prefix_org_setup = "org_setup_commons001"
prefix_project_setup = "project_setup_commons001"

### Uncomment this if not using our makefiles
#terraform_workspace = "commmons001_setup"