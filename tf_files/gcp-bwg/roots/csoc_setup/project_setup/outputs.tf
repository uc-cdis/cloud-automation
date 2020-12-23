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
  value       = "${module.vpc-csoc-ingress.network_self_link}"
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
  value       = "${module.vpc-csoc-egress.network_self_link}"
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

######################################################################

#######################################################################
output "peer1_state_details" {
  value = "${module.vpc-peering-csoc_private_to_ingress.peer1_state_details}"
}

output "peer1_vpc_state" {
  value = "${module.vpc-peering-csoc_private_to_ingress.peer1_vpc_state}"
}

output "peer2_state_details" {
  value = "${module.vpc-peering-csoc_private_to_ingress.peer2_state_details}"
}

output "peer2_vpc_state" {
  value = "${module.vpc-peering-csoc_private_to_ingress.peer2_vpc_state}"
}

############### CLOUD NAT OUTPUTS #####################
output "cloud_nat_name" {
  value = "${module.create_cloud_nat_csoc_private.cloud_nat_name}"
}

output "cloud_router_name" {
  value = "${module.create_cloud_nat_csoc_private.cloud_router_name}"
}

output "cloud_nat_external_ip_self_link" {
  value = "${module.create_cloud_nat_csoc_private.google_compute_address_self_link}"
}

output "cloud_nat_external_ip" {
  value = "${module.create_cloud_nat_csoc_private.google_compute_address_ip}"
}

############### FIREWALL OUTPUTS #####################
# -----------------
# Firewall Outputs
# -----------------
// VPC-CSOC-EGRESS
output "firewall-csoc-egress-inboud-proxy-port-self-link" {
  value = "${module.firewall-csoc-egress-inboud-proxy-port.firewall_self_link}"
}

output "firewall-csoc-egress-inboud-proxy-port-target-tags" {
  value = ["${module.firewall-csoc-egress-inboud-proxy-port.firewall_target_tags}"]
}

output "firewall-csoc-egress-outbound-web-self-link" {
  value = "${module.firewall-csoc-egress-outbound-web.firewall_egress_self_link}"
}

output "firewall-csoc-egress-outbound-web-target-tags" {
  value = ["${module.firewall-csoc-egress-outbound-web.firewall_egress_target_tags}"]
}

// VPC-CSOC-INGRESS
/*
output "firewall-csoc-ingress-inbound-https-self-link" {
  value = "${module.firewall-csoc-ingress-inbound-https.firewall_self_link}"
}

output "firewall-csoc-ingress-inbound-https-target-tags" {
  value = "${module.firewall-csoc-ingress-inbound-https.firewall_target_tags}"
}

output "firewall-csoc-ingress-inbound-ssh-self-link" {
  value = "${module.firewall-csoc-ingress-inbound-ssh.firewall_self_link}"
}

output "firewall-csoc-ingress-inbound-ssh-target-tags" {
  value = "${module.firewall-csoc-ingress-inbound-ssh.firewall_target_tags}"
}
*/

output "firewall-csoc-ingress-inbound-openvpn-self-link" {
  value = "${module.firewall-csoc-ingress-inbound-openvpn.firewall_self_link}"
}

output "firewall-csoc-ingress-inbound-openvpn-target-tags" {
  value = ["${module.firewall-csoc-ingress-inbound-openvpn.firewall_target_tags}"]
}

output "firewall-csoc-ingress-outbound-proxy-self-link" {
  value = "${module.firewall-csoc-ingress-outbound-proxy.firewall_egress_self_link}"
}

output "firewall-csoc-ingress-outbound-proxy-target-tags" {
  value = ["${module.firewall-csoc-ingress-outbound-proxy.firewall_egress_target_tags}"]
}

output "firewall_csoc_egress_allow_openvpn-target-tags" {
  value = ["${module.firewall_csoc_egress_allow_openvpn.firewall_egress_target_tags}"]
}

output "firewall_csoc_ingress_outbound_ssh_target_tags" {
  value = ["${module.firewall_csoc_ingress_outbound_ssh.firewall_egress_target_tags}"]
}

// VPC-CSOC-PRIVATE
output "firewall-csoc-private-inbound-ssh-self-link" {
  value = "${module.firewall-csoc-private-inbound-ssh.firewall_self_link}"
}

output "firewall-csoc-private-inbound-ssh-target-tags" {
  value = ["${module.firewall-csoc-private-inbound-ssh.firewall_target_tags}"]
}

output "firewall-csoc-private-inbound-qualys-udp-self-link" {
  value = "${module.firewall-csoc-private-inbound-qualys-udp.firewall_self_link}"
}

output "firewall-csoc-private-inbound-qualys-udp-target-tags" {
  value = "${module.firewall-csoc-private-inbound-qualys-udp.firewall_target_tags}"
}

output "firewall-csoc-private-inbound-qualys-tcp-self-link" {
  value = "${module.firewall-csoc-private-inbound-qualys-tcp.firewall_self_link}"
}

output "firewall-csoc-private-inbound-qualys-tcp-target-tags" {
  value = "${module.firewall-csoc-private-inbound-qualys-tcp.firewall_target_tags}"
}

output "firewall-csoc-private-inboud-gke-target-tags" {
  value = "${module.firewall-inbound-gke.firewall_target_tags}"
}

output "firewall-csoc-private-outbound-ssh-self-link" {
  value = "${module.firewall-csoc-private-outbound-ssh.firewall_egress_self_link}"
}

output "firewall-csoc-private-outbound-ssh-target-tags" {
  value = ["${module.firewall-csoc-private-outbound-ssh.firewall_egress_target_tags}"]
}

output "firewall-csoc-private-outbound-qualys-update-self-link" {
  value = "${module.firewall-csoc-private-outbound-qualys-update.firewall_egress_self_link}"
}

output "firewall-csoc-private-outbound-qualys-update-target-tags" {
  value = "${module.firewall-csoc-private-outbound-qualys-update.firewall_egress_target_tags}"
}

output "firewall-csoc-private-outbound-qualys-udp-self-link" {
  value = "${module.firewall-csoc-private-outbound-qualys-udp.firewall_egress_self_link}"
}

output "firewall-csoc-private-outbound-qualys-udp-target-tags" {
  value = "${module.firewall-csoc-private-outbound-qualys-udp.firewall_egress_target_tags}"
}

output "firewall-csoc-private-outbound-qualys-tcp-self-link" {
  value = "${module.firewall-csoc-private-outbound-qualys-tcp.firewall_egress_self_link}"
}

output "firewall-csoc-private-outbound-qualys-tcp-target-tags" {
  value = "${module.firewall-csoc-private-outbound-qualys-tcp.firewall_egress_target_tags}"
}

output "firewall-csoc-private-outbound-proxy-self-link" {
  value = "${module.firewall-csoc-private-outbound-proxy.firewall_egress_self_link}"
}

output "firewall-csoc-private-outbound-proxy-target-tags" {
  value = ["${module.firewall-csoc-private-outbound-proxy.firewall_egress_target_tags}"]
}

output "firewall-csoc-private-outbound-gke-target-tags" {
  value = ["${module.firewall-outbound-gke.firewall_egress_target_tags}"]
}
