# Service account needs Folder IAM Admin rights.
# Service account needs Org Admin rights to assign rights. Tried other roles like
# Org Role Admin/Org Policy Admin. Orginization Administrator was only role that works.
#
#
# Added Folder IAM Admin role to SA "tf-deploy-210"
# Added Organization Administrator role to SA 'tf-deploy-210"
# Added Storage Admin role to SA "tf-deploy-210"

# All roles found here: https://cloud.google.com/iam/docs/understanding-roles
/*
locals {
  compute_instance_viewer_folder_binding = "${var.compute_instance_viewer_folder_binding}"
}
*/
# -----------------------------------
# Assign Roles at Org Level
# -----------------------------------
resource "google_organization_iam_binding" "org_administrator_org_binding" {
  count = "${length(var.org_administrator_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/resourcemanager.organizationAdmin"

  members = "${var.org_administrator_org_binding}"
}

resource "google_organization_iam_binding" "org_viewer_org_binding" {
  count = "${length(var.org_viewer_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/resourcemanager.organizationViewer"

  members = "${var.org_viewer_org_binding}"
}

resource "google_organization_iam_binding" "network_admin_org_binding" {
  count = "${length(var.network_admin_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/compute.networkAdmin"

  members = "${var.network_admin_org_binding}"
}

# Instead of a primitive role, roles/resourcemanager.ProjectCreator could be used instead. Applied at folder lvl vs Org lvl.
resource "google_organization_iam_binding" "all_projects_org_owner" {
  count = "${length(var.all_projects_org_owner) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/owner"

  members = "${var.all_projects_org_owner}"
}

resource "google_organization_iam_binding" "billing_account_admin" {
  count = "${length(var.billing_account_admin) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/billing.admin"

  members = "${var.billing_account_admin}"
}

resource "google_organization_iam_binding" "billing_account_user" {
  count = "${length(var.billing_account_user) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/billing.user"

  members = "${var.billing_account_user}"
}

resource "google_organization_iam_binding" "billing_account_viewer" {
  count = "${length(var.billing_account_viewer) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/billing.user"

  members = "${var.billing_account_viewer}"
}

resource "google_organization_iam_binding" "log_viewer_org_binding" {
  count = "${length(var.log_viewer_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/logging.viewer"

  members = "${var.log_viewer_org_binding}"
}

resource "google_organization_iam_binding" "projects_viewer_org_binding" {
  count = "${length(var.projects_viewer_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/viewer"

  members = "${var.projects_viewer_org_binding}"
}

resource "google_organization_iam_binding" "org_policy_viewer_org_binding" {
  count = "${length(var.org_policy_viewer_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/orgpolicy.policyViewer"

  members = "${var.org_policy_viewer_org_binding}"
}

resource "google_organization_iam_binding" "folder_viewer_org_binding" {
  count = "${length(var.folder_viewer_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/resourcemanager.folderViewer"

  members = "${var.folder_viewer_org_binding}"
}

resource "google_organization_iam_binding" "stackdriver_monitoring_viewer_org_binding" {
  count = "${length(var.stackdriver_monitoring_viewer_org_binding) > 0 ? 1 : 0}"

  org_id = "${var.org_iam_binding}"
  role   = "roles/monitoring.viewer"

  members = "${var.stackdriver_monitoring_viewer_org_binding}"
}

# -----------------------------------
# Assign Roles at Folder Level
# -----------------------------------
data "google_folder" "production" {
  count = "${length(var.folder_iam_binding)}"

  folder = "folders/${element(var.folder_iam_binding, count.index)}"
}

// Kubernetes Cluster Viewer
resource "google_folder_iam_binding" "kubernetes_cluster_viewer_folder_binding" {
  count = "${length(var.kubernetes_cluster_viewer_folder_binding) > 0 ? length(var.folder_iam_binding) : 0}"

  folder  = "folders/${element(data.google_folder.production.*.id, count.index)}"
  role    = "roles/container.clusterViewer"
  members = "${var.kubernetes_cluster_viewer_folder_binding}"
}

// Kubernetes Engine Veiwer
resource "google_folder_iam_binding" "kubernetes_engine_viewer_folder_binding" {
  count = "${length(var.kubernetes_engine_viewer_folder_binding) > 0 ? length(var.folder_iam_binding) : 0}"

  folder  = "folders/${element(data.google_folder.production.*.id, count.index)}"
  role    = "roles/container.viewer"
  members = "${var.kubernetes_engine_viewer_folder_binding}"
}

// Stackdriver Account Viewer
resource "google_folder_iam_binding" "stackdriver_monitoring_viewer_folder_binding" {
  count = "${length(var.stackdriver_monitoring_viewer_folder_binding) > 0 ? length(var.folder_iam_binding) : 0}"

  folder = "folders/${element(data.google_folder.production.*.id, count.index)}"
  role   = "roles/monitoring.viewer"

  members = "${var.stackdriver_monitoring_viewer_folder_binding}"
}

// Log Viewer (does not have access to private logs)
// To grant private logs: roles/privateLogViewer
resource "google_folder_iam_binding" "log_viewer_folder_binding" {
  count = "${length(var.log_viewer_folder_binding) > 0 ? length(var.folder_iam_binding) : 0}"

  folder = "folders/${element(data.google_folder.production.*.id, count.index)}"
  role   = "roles/logging.viewer"

  members = "${var.log_viewer_folder_binding}"
}

resource "google_folder_iam_binding" "service_account_creator_folder_level" {
  count = "${length(var.service_account_creator_folder_level) > 0 ? length(var.folder_iam_binding) : 0}"

  folder = "folders/${element(data.google_folder.production.*.id, count.index)}"
  role   = "roles/iam.serviceAccountAdmin"

  members = "${var.service_account_creator_folder_level}"
}

# -----------------------------------
# Assign Roles for Cloud Storage
# -----------------------------------
// Data Resource for storage bucket
data "google_storage_bucket_object" "bucket_name_iam" {
  count = "${length(var.bucket_name_iam)}"

  bucket = "${element(var.bucket_name_iam, count.index)}"
}

resource "google_storage_bucket_iam_binding" "cloud_storage_viewer" {
  count = "${length(var.cloud_storage_viewer) > 0 ? length(var.bucket_name_iam) : 0}"

  bucket = "${element(data.google_storage_bucket_object.bucket_name_iam.*.id, count.index)}"
  role   = "roles/storage.objectViewer"

  members = "${var.cloud_storage_viewer}"
}

# -----------------------------------
# CSOC Roles
# -----------------------------------
resource "google_folder_iam_binding" "compute_instance_viewer_folder_binding" {
  count = "${length(var.compute_instance_viewer_folder_binding) > 0 ? length(var.folder_iam_binding) : 0}"

  folder = "folders/${element(data.google_folder.production.*.id, count.index)}"
  role   = "roles/compute.viewer"

  members = "${var.compute_instance_viewer_folder_binding}"
}
