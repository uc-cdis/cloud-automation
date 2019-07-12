resource "google_compute_firewall" "fw-rule" {
  provider       = "google-beta"
  enable_logging = "${var.enable_logging}"
  project        = "${var.project_id}"
  direction      = "${var.direction}"
  priority       = "${var.priority}"

  name        = "${var.name}"
  network     = "${var.network}"
  description = "Creates Firewall rule targetting tagged instances"

  allow {
    protocol = "${var.protocol}"
    ports    = ["${var.ports}"]
  }

  target_tags   = ["${var.target_tags}"]
  source_ranges = ["${var.source_ranges}"]
}
