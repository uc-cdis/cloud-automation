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

  kubernetes_cluster_viewer_folder_binding     = "${var.kubernetes_cluster_viewer_folder_binding}"
  kubernetes_cluster_viewer_folder_binding     = "${var.kubernetes_cluster_viewer_folder_binding}"
  kubernetes_engine_viewer_folder_binding      = "${var.kubernetes_engine_viewer_folder_binding}"
  stackdriver_monitoring_viewer_folder_binding = "${var.stackdriver_monitoring_viewer_folder_binding}"
  log_viewer_folder_binding                    = "${var.log_viewer_folder_binding}"
  compute_instance_viewer_folder_binding       = "${var.compute_instance_viewer_folder_binding}"
  service_account_creator_folder_level         = "${var.service_account_creator_folder_level}"
}

/*************************
 Create New Project
 ************************/

module "project" {
  source                      = "../../../modules/project"
  organization                = "organizations/${data.google_organization.org.id}"
  project_name                = "${var.project_name}"
  folder_id                   = "${module.folders.folder_id}"
  region                      = "${var.region}"
  billing_account             = "${var.billing_account}"
  enable_apis                 = "true"
  disable_services_on_destroy = "true"

  add_csoc_service_account = true
  csoc_project_id          = "${data.terraform_remote_state.org_setup_csoc.project_number}"

  activate_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "containerregistry.googleapis.com",
    "storage-api.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
}
