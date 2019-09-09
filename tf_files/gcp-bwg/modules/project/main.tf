resource "random_id" "id" {
  byte_length = 4
  prefix      = "${var.project_name}-"
}

resource "google_project" "project" {
  count               = "${var.set_parent_folder == true ? 1:0}"
  name                = "${var.project_name}"
  project_id          = "${random_id.id.hex}"
  billing_account     = "${var.billing_account}"
  folder_id           = "${var.folder_id}"
  auto_create_network = "${var.auto_create_network}"

  labels {
    "data-commons" = "${var.project_name}"

    #"department" = "bsd"
    #"environment" = "development"
    #"sponsor" = "sponsor label"
  }
}

resource "google_project_service" "project" {
  count                      = "${var.enable_apis ? length(var.activate_apis) : 0}"
  project                    = "${google_project.project.project_id}"
  service                    = "${element(var.activate_apis, count.index)}"
  disable_on_destroy         = "${var.disable_services_on_destroy}"
  disable_dependent_services = "true"

  depends_on = ["google_project.project"]
}

// Add the GCE default service as a GKE Viewer
resource "google_project_iam_binding" "kubernetes_engine_viewer_folder_binding" {
  count = "${var.add_csoc_service_account ? 1 : 0}"  
  project = "${google_project.project.project_id}"
  role    = "roles/container.viewer"
  members = ["serviceAccount:${var.csoc_project_id}-compute@developer.gserviceaccount.com"]

  depends_on = ["google_project.project"]
}
