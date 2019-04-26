output "network_name_csoc_private" {
  value       = "${module.vpc-csoc-private.network_name}"
  description = "The name of the VPC being created"
}

output "network_self_link_csoc_private" {
  value       = "${module.vpc-csoc-private.network_self_link}"
  description = "The URI of the VPC being created"
}

output "network_subnetwork_csoc_private" {
  value = "${module.vpc-csoc-private.network_subnetwork_noalias}"
}

output "network_id_csoc_private" {
  value = "${module.vpc-csoc-private.network_id}"
}

output "subnetwork_self_link_csoc_private" {
  value = "${module.vpc-csoc-private.subnetwork_self_link_noalias}"
}

output "secondary_range_name_csoc_private" {
  value = ["${module.vpc-csoc-private.secondary_range_name}"]
}
output "network_name_csoc_ingress" {
  value       = "${module.vpc-csoc-ingress.network_name}"
  description = "The name of the VPC being created"
}

output "network_self_link_csoc_ingress" {
  value       = "${module.vpc-csoc-private.network_self_link}"
  description = "The URI of the VPC being created"
}

output "network_subnetwork_csoc_ingress" {
  value = "${module.vpc-csoc-ingress.network_subnetwork_noalias}"
}

output "network_id_csoc_ingress" {
  value = "${module.vpc-csoc-ingress.network_id}"
}

output "subnetwork_self_link_csoc_ingress" {
  value = "${module.vpc-csoc-ingress.subnetwork_self_link_noalias}"
}

output "secondary_range_name_csoc_ingress" {
  value = ["${module.vpc-csoc-ingress.secondary_range_name}"]
}

output "network_name_csoc_egress" {
  value       = "${module.vpc-csoc-egress.network_name}"
  description = "The name of the VPC being created"
}

output "network_self_link_csoc_egress" {
  value       = "${module.vpc-csoc-private.network_self_link}"
  description = "The URI of the VPC being created"
}

output "network_subnetwork_csoc_egress" {
  value = "${module.vpc-csoc-egress.network_subnetwork_noalias}"
}

output "network_id_csoc_egress" {
  value = "${module.vpc-csoc-egress.network_id}"
}

output "subnetwork_self_link_csoc_egress" {
  value = "${module.vpc-csoc-egress.subnetwork_self_link_noalias}"
}

output "secondary_range_name_csoc_egress" {
  value = ["${module.vpc-csoc-egress.secondary_range_name}"]
}

output "ssh_ingress_self_link" {
  value = "${module.firewall-inbound-ssh.firewall_self_link}"
}

output "ssh_ingress_ports" {
  value = "${module.firewall-inbound-ssh.firewall_ports}"
}

output "ssh_ingress_target_tags" {
  value = "${module.firewall-inbound-ssh.firewall_target_tags}"
}

output "http_ingress__self_link" {
  value = "${module.firewall-inbound-http.firewall_self_link}"
}

output "http_ingress_ports" {
  value = "${module.firewall-inbound-ssh.firewall_ports}"
}

output "http_ingress_target_tags" {
  value = "${module.firewall-inbound-http.firewall_target_tags}"
}

output "https_ingress_self_link" {
  value = "${module.firewall-inbound-https.firewall_self_link}"
}

output "https_ingress_ports" {
  value = "${module.firewall-inbound-ssh.firewall_ports}"
}

output "https_ingress_target_tags" {
  value = "${module.firewall-inbound-https.firewall_target_tags}"
}
