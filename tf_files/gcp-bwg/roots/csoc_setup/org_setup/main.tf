
# The service account used to run Terraform when creating 
# a google_folder resource must have roles/resourcemanager.folderCreator.

/*************************
 Create New Folders
 ************************/

data "google_organization" "org" {
  domain = "${var.organization}"
}

module "folders" {
  source        = "../../../modules/folders"
  parent_folder = "organizations/${data.google_organization.org.id}"
  display_name  = "${var.folder}"
  create_folder = "${var.create_folder}"
}


/*************************
 Create New Project
 ************************/

module "project" {

  source 		      = "../../../modules/project"
  organization                = "organizations/${data.google_organization.org.id}"
  project_name                = "${var.project_name}"
  folder_id                   = "${module.folders.folder_id}"
  region                      = "${var.region}"
  billing_account             = "${var.billing_account}"
  enable_apis                 = "true"
  disable_services_on_destroy = "true"

  activate_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "containerregistry.googleapis.com",
    "storage-api.googleapis.com",
  ]
}

