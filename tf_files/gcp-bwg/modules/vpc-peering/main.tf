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

  depends_on = ["google_compute_network_peering.peering1", "null_resource.force_networks_in_order"]
}

# Have the resource wait long enough to create the peer1
resource "null_resource" "force_networks_in_order" {
  provisioner "local-exec" {
    command = "echo ${google_compute_network_peering.peering1.id}"
  }
}
