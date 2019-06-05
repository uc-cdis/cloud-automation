output "private_ip" {
  description = "list private ip on compute instance"
  value       = "${google_compute_instance.default.*.network_interface.0.network_ip}"
}
