output "firewall_self_link" {
  value       = "${google_compute_firewall.fw-rule.self_link}"
  description = "The URI of the created resource"
}

output "firewall_target_tags" {
  value       = ["${google_compute_firewall.fw-rule.target_tags}"]
  description = "The URI of the created resource"
}

output "firewall_ports" {
  value       = ["${google_compute_firewall.fw-rule.allow}"]
  description = "The URI of the created resource"
}
