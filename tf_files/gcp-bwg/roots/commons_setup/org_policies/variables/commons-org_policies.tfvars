########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info

env = "commons001"
project_name = "<seed_project_here>" # seed project name here
#billing_account = "<billing_account_here>"
credential_file = "<credentials_here>.json"
create_folder = true
set_parent_folder = true
#folder = "<folder_name_here>"
region = "us-central1"
organization = "<organization_name_here>"
org_id = "<org_id_here>"
###### Terraform State
state_bucket_name = "<tfstate_bucket_here>"
prefix_org_policies = "org_policies_commons001"
#prefix_org_setup = "org_setup_commons0001"
#prefix_project_setup = "project_setup_commons001"

### Add addition constraints if desired
constraint = ["constraints/compute.disableNestedVirtualization","constraints/compute.disableSerialPortAccess","constraints/compute.skipDefaultNetworkCreation"]


### Uncomment this if not using our makefiles
#terraform_workspace = "commmons001_setup"

### Uncomment to add specific roles
#org_administrator_org_binding=[]
#projects_viewer_org_binding = []
#org_viewer_org_binding = []
#network_admin_org_binding = []
#all_projects_org_owner = []
#billing_account_admin = []
#billing_account_user = []
#billing_account_viewer = []
#log_viewer_org_binding = []
#org_policy_viewer_org_binding = []
#folder_viewer_org_binding = []
#stackdriver_monitoring_viewer_org_binding = []


### Uncomment to add external IP Access
#org_iam_externalipaccess = []