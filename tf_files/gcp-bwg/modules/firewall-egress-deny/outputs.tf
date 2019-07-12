output "firewall_egress_self_link" {
  value = "${google_compute_firewall.rule.self_link}"
}

/*
output "firewall_egress_target_tags" {
    value = "${google_compute_firewall.rule.target_tags}"
}
*/

