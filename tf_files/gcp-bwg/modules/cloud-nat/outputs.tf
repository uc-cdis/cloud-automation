output "cloud_nat_name" {
  value = "${google_compute_router_nat.simple_nat.name}"
}

output "cloud_router_name" {
  value = "${google_compute_router.router.name}"
}

output "google_compute_address_self_link" {
  value = ["${google_compute_address.address.*.self_link}"]
}

output "google_compute_address_ip" {
  value = ["${google_compute_address.address.*.address}"]
}
