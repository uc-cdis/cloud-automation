output "network_name_commons_private" {
  value       = "${module.vpc-commons-private.network_name}"
  description = "The name of the VPC being created"
}

output "network_self_link_commons_private" {
  value       = "${module.vpc-commons-private.network_self_link}"
  description = "The URI of the VPC being created"
}

output "network_subnetwork_commons_private" {
  value = "${module.vpc-commons-private.network_subnetwork}"
}

output "network_id_commons_private" {
  value = "${module.vpc-commons-private.network_id}"
}

output "subnetwork_name__commons_private" {
  value = "${module.vpc-commons-private.subnetwork_name}"
}

output "subnetwork_self_link_commons_private" {
  value = "${module.vpc-commons-private.subnetwork_self_link}"
}

output "secondary_range_name_commons_private" {
  value = ["${module.vpc-commons-private.secondary_range_name}"]
}

######################################################################
/*
output "firewall_ingress_self_link" {
  value = "${module.firewall-inbound-commons.firewall_self_link}"
}

output "firwall_ingress_ports" {
  value = "${module.firewall-inbound-commons.firewall_ports}"
}

output "firewall_ingress_target_tags" {
  value = "${module.firewall-inbound-commons.firewall_target_tags}"
}


output "firewall_egress__self_link" {
  value = "${module.firewall-outbound-commons.firewall_self_link}"
}

output "firewall_egress_ports" {
  value = "${module.firewall-inbound-commons.firewall_ports}"
}

output "firewall_egress_target_tags" {
  value = "${module.firewall-outbound-commons.firewall_target_tags}"
}
*/

output "firewall_egress_allow_squid_mig_target_tags" {
  value = "${module.firewall_commons_egress_allow_squid_mig.firewall_egress_target_tags}"
}

output "firewall_commons_egress_allow_proxy_port_target_tags" {
  value = "${module.firewall_commons_egress_allow_proxy_port.firewall_egress_target_tags}"
}

output "firewall_inbound_proxy_port_target_tags" {
  value = "${module.firewall_inbound_proxy_port.firewall_target_tags}"
}
