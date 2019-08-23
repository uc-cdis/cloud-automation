resource "google_compute_address" "address" {
  count   = "${var.nat_external_address_count}"
  name    = "nat-external-address-${count.index}"
  region  = "${var.region}"
  project = "${var.project_id}"
}

resource "google_compute_router" "router" {
  name    = "${var.router_name}"
  region  = "${var.region}"
  network = "${var.network_self_link}"
  project = "${var.project_id}"
}

resource "google_compute_router_nat" "simple_nat" {
  name                               = "${var.nat_name}"
  router                             = "${google_compute_router.router.name}"
  region                             = "${var.region}"
  nat_ip_allocate_option             = "${var.nat_ip_allocate_option}"
  nat_ips                            = ["${google_compute_address.address.*.self_link}"]
  source_subnetwork_ip_ranges_to_nat = "${var.source_subnetwork_ip_ranges_to_nat}"
  project                            = "${var.project_id}"

  log_config {
    filter = "${var.log_filter}"
    enable = "${var.log_filter_enable}"
  }
}
