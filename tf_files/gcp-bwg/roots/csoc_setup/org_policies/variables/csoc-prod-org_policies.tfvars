########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info

env = "csoc-prods"
project_name = "<project_here>" # Seed account
credential_file = "../credentials.json"
create_folder = true
set_parent_folder = true
folder = "csoc-prods"
region = "us-central1"
organization = "<organization_here>"
org_id = "<organization_id_here>"
prefix_org_setup = "org_setup_csoc"
prefix_project_setup = "project_setup_csoc"
prefix_org_policies = "org_policies"
state_bucket_name = "<state_bucket_here>"
constraint = ["constraints/compute.disableNestedVirtualization","constraints/compute.disableSerialPortAccess","constraints/compute.skipDefaultNetworkCreation"]


### Uncomment this if not using our makefiles
#terraform_workspace = "csoc_setup"

#org_administrator_org_binding=[""]
#projects_viewer_org_binding = [""]
#org_viewer_org_binding = [""]
#network_admin_org_binding = [""]
#all_projects_org_owner = [""]
#billing_account_admin = [""]
#billing_account_user = [""]
#billing_account_viewer = [""]
#log_viewer_org_binding = [""]
#org_policy_viewer_org_binding = [""]
#folder_viewer_org_binding = [""]
#stackdriver_monitoring_viewer_org_binding = [""]

#org_iam_externalipaccess = []