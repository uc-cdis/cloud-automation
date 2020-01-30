# ----------------------------------------------------------
#   CHECK NETWORK DATA
# ----------------------------------------------------------

data "google_compute_network" "network" {
  project = "${var.project}"
  name    = "${var.network_interface}"
}

data "google_compute_subnetwork" "subnetwork" {
  project = "${var.project}"
  name    = "${var.subnetwork}"
}

# ----------------------------------------------------------
#   CREATE INSTANCE TEMPLATE
# ----------------------------------------------------------

resource "google_compute_instance_template" "instance_template" {
  name_prefix        = "${var.name}-${var.instance_template_name}"
  project     = "${var.project}"
  description = "Managed by Terraform. This template is used to create ${var.name} instances."

  labels = "${var.labels}"

  tags = ["${var.tags}"]

  network_interface {
    network       = "${data.google_compute_network.network.self_link}"
    subnetwork    = "${data.google_compute_subnetwork.subnetwork.self_link}"
    access_config = ["${var.access_config}"]
  }

  can_ip_forward = "${var.can_ip_forward}"

  instance_description = "Google Compute Instance With ${var.name}"
  machine_type         = "${var.machine_type}"

  scheduling {
    automatic_restart   = "${var.automatic_restart}"
    on_host_maintenance = "${var.on_host_maintenance}"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "${var.source_image}"
    auto_delete  = true
    boot         = true
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata_startup_script = "${file("${var.metadata_startup_script}")}"

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

# ----------------------------------------------------------
#   CREATE INSTANCE GROUP
# ----------------------------------------------------------

resource "google_compute_instance_group_manager" "instance_group" {
  project            = "${var.project}"
  name               = "${var.name}-${var.instance_group_manager_name}"
  base_instance_name = "${var.name}-${var.base_instance_name}"
  instance_template  = "${google_compute_instance_template.instance_template.self_link}"
  zone               = "${var.zone}"

  #target_pools = ["${google_compute_target_pool.target_pool.self_link}"]
  target_size = "${var.target_size}"
}
