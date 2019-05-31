output "network_name_commons001-dev_private" {
  value       = "${module.vpc-commons001-dev-private.network_name}"
  description = "The name of the VPC being created"
}

output "network_self_link_commons001-dev_private" {
  value       = "${module.vpc-commons001-dev-private.network_self_link}"
  description = "The URI of the VPC being created"
}

output "network_subnetwork_commons001-dev_private" {
  value = "${module.vpc-commons001-dev-private.network_subnetwork}"
}

output "network_id_commons001-dev_private" {
  value = "${module.vpc-commons001-dev-private.network_id}"
}

output "subnetwork_self_link_commons001-dev_private" {
  value = "${module.vpc-commons001-dev-private.subnetwork_self_link}"
}

output "secondary_range_name_commons001-dev_private" {
  value = ["${module.vpc-commons001-dev-private.secondary_range_name}"]
}
######################################################################
output "firewall_ingress_self_link" {
  value = "${module.firewall-inbound-commons001-dev.firewall_self_link}"
}

output "firwall_ingress_ports" {
  value = "${module.firewall-inbound-commons001-dev.firewall_ports}"
}

output "firewall_ingress_target_tags" {
  value = "${module.firewall-inbound-commons001-dev.firewall_target_tags}"
}
/*
output "firewall_egress__self_link" {
  value = "${module.firewall-outbound-commons001-dev.firewall_self_link}"
}

output "firewall_egress_ports" {
  value = "${module.firewall-inbound-commons001-dev.firewall_ports}"
}

output "firewall_egress_target_tags" {
  value = "${module.firewall-outbound-commons001-dev.firewall_target_tags}"
}
*/
