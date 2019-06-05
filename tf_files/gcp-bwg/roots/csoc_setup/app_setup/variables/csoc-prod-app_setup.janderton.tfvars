########################################################
#
#   Vars for creating project level related resources
#   (ie. vpc, firewall rules, vpc-peering, etc.)
#
########################################################

#####Project setup info
project_name = "jca-uchi-tf-csoc-c465eb2e"
billing_account = "01A7C1-F7ECC5-A7181E"
credential_file = "../credentials.json"
create_folder = true
set_parent_folder = true
folder = "csoc-production"
region = "us-central1"
organization = "prorelativity.com"
org_id = "575228741867"
prefix_org_setup = "org_setup_csoc"
prefix_project_setup = "org_setup_csoc"
prefix_org_policies = "org_policies"
prefix_app_setup = "app_setup_csoc"

state_bucket_name = "jca-uchi-tf-state"
env = "csoc-prod"
environment = "csoc-prod"

#### Uncomment this if not using our makefiles
#terraform_workspace = "csoc_setup"


# Compute Instance Variables
instance_name = "adminvm"
bastion_name = "bastionvm"
image_name = "ubuntu-1604-lts"
count_compute = "1"
count_start  = "1"
machine_type_dev = "g1-small"
machine_type_prod = "n1-standard-1"

# Tags and Label Variables
compute_tags = ["csoc-ingress-from-csoc-private", "csoc-ingress-to-csoc-private", "csoc-private-from-commons001","ssh-in-csoc-private","inbound-to-commons001","web-access"]
bastion_compute_tags = ["csoc-ingress-from-csoc-private", "csoc-ingress-to-csoc-private", "csoc-private-from-commons001","ssh-in","web-access"]
compute_labels = {
    "department"  = "ctds"
    "sponsor"     = "sponsor"
    "envrionment" = "development"
    "datacommons" = "commons"
  }

# Boot-disk Variables
size = "15"
type = "pd-standard"
auto_delete = "true"

# Network Interface Variables
subnetwork_name = "csoc-private-kubecontrol"
ingress_subnetwork_name = "csoc-ingress-kubecontrol"

# Service Account block
  scopes = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/service.management",
    "https://www.googleapis.com/auth/devstorage.full_control",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
#scopes = [
#  "userinfo-email", "compute-ro", "storage-ro", "cloud-platform", "service.management"
#]

# Scheduling
automatic_restart = "true"
on_host_maintenance = "MIGRATE"


