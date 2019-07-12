# Top-level folder under an organization.
resource "google_folder" "department" {
  count        = "${var.create_folder ? 1 : 0}"
  display_name = "${var.display_name}"
  parent       = "${var.parent_folder}"
}

# -----------------------------------
# Assign Roles at Folder Level
# -----------------------------------
// Kubernetes Cluster Viewer
resource "google_folder_iam_binding" "kubernetes_cluster_viewer_folder_binding" {
  count = "${length(var.kubernetes_cluster_viewer_folder_binding)}"

  folder  = "${google_folder.department.name}"
  role    = "roles/container.clusterViewer"
  members = "${var.kubernetes_cluster_viewer_folder_binding}"
}

// Kubernetes Engine Veiwer
resource "google_folder_iam_binding" "kubernetes_engine_viewer_folder_binding" {
  count = "${length(var.kubernetes_engine_viewer_folder_binding)}"

  folder  = "${google_folder.department.name}"
  role    = "roles/container.viewer"
  members = "${var.kubernetes_engine_viewer_folder_binding}"
}

// Stackdriver Account Viewer
resource "google_folder_iam_binding" "stackdriver_monitoring_viewer_folder_binding" {
  count = "${length(var.stackdriver_monitoring_viewer_folder_binding)}"

  folder = "${google_folder.department.name}"
  role   = "roles/monitoring.viewer"

  members = "${var.stackdriver_monitoring_viewer_folder_binding}"
}

// Log Viewer (does not have access to private logs)
// To grant private logs: roles/privateLogViewer
resource "google_folder_iam_binding" "log_viewer_folder_binding" {
  count = "${length(var.log_viewer_folder_binding)}"

  folder = "${google_folder.department.name}"
  role   = "roles/logging.viewer"

  members = "${var.log_viewer_folder_binding}"
}

resource "google_folder_iam_binding" "service_account_creator_folder_level" {
  count = "${length(var.service_account_creator_folder_level)}"

  folder = "${google_folder.department.name}"
  role   = "roles/iam.serviceAccountAdmin"

  members = "${var.service_account_creator_folder_level}"
}

resource "google_folder_iam_binding" "compute_instance_viewer_folder_binding" {
  count = "${length(var.compute_instance_viewer_folder_binding)}"

  folder = "${google_folder.department.name}"
  role   = "roles/compute.viewer"

  members = "${var.compute_instance_viewer_folder_binding}"
}
