# Network Peering

resource "google_compute_network_peering" "peering1" {
  name               = "${var.peer1_name}"
  network            = "${var.project_id}"
  peer_network       = "${var.csoc_project_id}"
  auto_create_routes = "${var.peer1_create_routes}"
}

resource "google_compute_network_peering" "peering2" {
  name               = "${var.peer2_name}"
  network            = "${var.csoc_project_id}"
  peer_network       = "${var.project_id}"
  auto_create_routes = "${var.peer2_create_routes}"
}
