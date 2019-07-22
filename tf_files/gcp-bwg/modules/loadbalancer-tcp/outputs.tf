output ip_address {
  description = "The ip address of the forwarding rule."
  value       = "${google_compute_forwarding_rule.default.ip_address}"
}
