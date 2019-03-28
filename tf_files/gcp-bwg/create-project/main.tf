terraform {
    # Specify terraform code version
    required_version = ">=0.11.7"

    # Specify Google provider version
    required_providers = {
        gcp = ">=2.1.0"
    }
}

provider "google" {
  credentials = "${file("${var.credential_file}")}"
  region = "${var.region}"
}
provider "google-beta" {
  credentials = "${file("${var.credential_file}")}"
  region = "${var.region}"
}


# Use folder ID instead of Org ID to put project in correct folder
# Service account has Billing Account User role. This role is very restricted.
# Must provide the billing account id.
module "project" {
    source = "../modules/project"
    project_name = "${var.project_name}"
    folder_id = "${var.folder_id}"
    region = "${var.region}"
    billing_account = "${var.billing_account}"
    enable_apis = "true"
    disable_services_on_destroy = "true"

  activate_apis = [
   "compute.googleapis.com",
   "sqladmin.googleapis.com",
   "container.googleapis.com",
   "iam.googleapis.com",
   "containerregistry.googleapis.com",   
   "storage-api.googleapis.com"
    ]
}