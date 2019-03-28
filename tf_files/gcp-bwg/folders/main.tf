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

# The service account used to run Terraform when creating 
# a google_folder resource must have roles/resourcemanager.folderCreator.


data "google_organization" "org" {
    domain = "${var.organization}"
}

module "staging-folder" {
  source = "../modules/folders"
  parent_folder = "organizations/${data.google_organization.org.id}"
  display_name = "${var.folder_staging}" 
}

module "prod-folder" {
  source = "../modules/folders"
  parent_folder = "organizations/${data.google_organization.org.id}"
  display_name = "${var.folder_prod}" 
}
