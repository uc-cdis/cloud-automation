output "peer1_state_details" {
  value = "${google_compute_network_peering.peering1.state_details}"
}

output "peer1_vpc_state" {
  value = "${google_compute_network_peering.peering1.state}"
}

output "peer2_state_details" {
  value = "${google_compute_network_peering.peering2.state_details}"
}

output "peer2_vpc_state" {
  value = "${google_compute_network_peering.peering2.state}"
}
