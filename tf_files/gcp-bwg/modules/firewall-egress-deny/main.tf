resource "google_compute_firewall" "rule" {
  provider       = "google-beta"
  enable_logging = "${var.enable_logging}"
  project        = "${var.project_id}"
  direction      = "${var.direction}"
  priority       = "${var.priority}"

  name    = "${lower(var.name)}-deny-all-outbound"
  network = "${var.network}"

  deny {
    protocol = "${var.protocol}"
    ports    = "${var.ports}"
  }

  target_tags        = "${var.target_tags}"
  destination_ranges = "${var.destination_ranges}"
}
