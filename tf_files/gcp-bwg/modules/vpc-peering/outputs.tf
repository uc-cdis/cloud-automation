output "peer1_state_details" {
  description = "Details about the current state of the peering for peer1."
  value       = "${google_compute_network_peering.peering1.state_details}"
}

output "peer1_vpc_state" {
  description = "State for the peering of peer1."
  value       = "${google_compute_network_peering.peering1.state}"
}

output "peer2_state_details" {
  description = "Details about the current state of the peering for peer2."
  value       = "${google_compute_network_peering.peering2.state_details}"
}

output "peer2_vpc_state" {
  description = "State for the peering of peer2."
  value       = "${google_compute_network_peering.peering2.state}"
}

output "network_link" {
  description = "Resource link of the peer network for peer2."
  value       = "${google_compute_network_peering.peering2.peer_network}"
}

output "peered_network_link" {
  description = "Resource link of the network to add a peering to for peer2."
  value       = "${google_compute_network_peering.peering2.network}"
}
