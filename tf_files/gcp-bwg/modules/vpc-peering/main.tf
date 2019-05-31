# Network Peering

resource "google_compute_network_peering" "peering1" {
  name               = "${var.peer1_name}"
  network            = "${var.peer1_root_self_link}"
  peer_network       = "${var.peer1_add_self_link}"
  auto_create_routes = "${var.auto_create_routes}"
}

resource "google_compute_network_peering" "peering2" {
  name               = "${var.peer2_name}"
  network            = "${var.peer2_root_self_link}"
  peer_network       = "${var.peer2_add_self_link}"
  auto_create_routes = "${var.auto_create_routes}"
}
