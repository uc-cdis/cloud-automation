resource "google_compute_instance" "default" {
  count = "${var.count_compute}"

  name         = "${format("%s-%d", var.instance_name, count.index + var.count_start)}"
  machine_type = "${var.environment == "prod" ? var.machine_type_prod : var.machine_type_dev }"
  zone         = "${element(data.google_compute_zones.available.names, count.index)}"
  project      = "${var.project}"

  tags = ["${var.compute_tags}"]

  labels = "${var.compute_labels}"

  boot_disk {
    initialize_params {
      image = "${var.image_name}"
      size  = "${var.size}"
      type  = "${var.type}"
    }

    auto_delete = "${var.auto_delete ? 1 : 0}"
  }

  // Local SSD disk
  #scratch_disk {}

  network_interface {
    subnetwork = "${data.google_compute_subnetwork.subnetwork.self_link}"

    # Ephemeral IP. Uncomment if needed
    # access_config {}
  }

  # Startup Script. Uncomment if needed
  #metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python-pip rsync; pip install flask"

  service_account {
    scopes = ["${var.scopes}"]
  }
  scheduling {
    automatic_restart   = "${var.automatic_restart ? 1 : 0}"
    on_host_maintenance = "${var.on_host_maintenance == "MIGRATE" ? "MIGRATE" : "TERMINATE"}"
  }
}
