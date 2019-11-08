/**********************************************
*      Create VPC csoc-private
**********************************************/

module "vpc-csoc-private" {
  source                      = "../../../modules/vpc"
  project_id                  = "${data.terraform_remote_state.org_setup.project_id}"
  network_name                = "${var.csoc_private_network_name}"
  create_vpc_secondary_ranges = "${var.create_vpc_secondary_ranges}"

  /*********************************************
                 define subnets
                *********************************************/
  subnets = [
    {
      subnet_name           = "${var.csoc_private_subnet_name}"
      subnet_ip             = "${var.csoc_private_subnet_ip}"
      subnet_region         = "${var.csoc_private_region}"
      subnet_flow_logs      = "${var.csoc_private_subnet_flow_logs}"
      subnet_private_access = "${var.csoc_private_subnet_private_access}"
    },
  ]

  /*********************************************
                 define subnet alias's ***** Look for k8s in vars and tfvars
                *********************************************/
  secondary_ranges = {
    "${var.csoc_private_subnet_name}" = [
      {
        range_name    = "${var.range_name_k8_service}"
        ip_cidr_range = "${var.ip_cidr_range_k8_service}"
      },
      {
        range_name    = "${var.range_name_k8_pod}"
        ip_cidr_range = "${var.ip_cidr_range_k8_pod}"
      },
    ]
  }

  /********************************************************
*      Create VPC route google_apis
********************************************************/

  routes = [
    {
      name              = "${var.csoc_private_network_name}-${var.google_apis_route}"
      destination_range = "199.36.153.4/30"
      next_hop_internet = "true"
    },
    {
      name              = "${var.csoc_private_network_name}-default-route"
      destination_range = "0.0.0.0/0"
      next_hop_internet = "true"
    },
  ]
}

############### End Create VPC##############################################################################
/**********************************************
*      Create VPC csoc-ingress
**********************************************/

module "vpc-csoc-ingress" {
  source                      = "../../../modules/vpc"
  project_id                  = "${data.terraform_remote_state.org_setup.project_id}"
  network_name                = "${var.csoc_ingress_network_name}"
  create_vpc_secondary_ranges = "${var.create_vpc_secondary_ranges}"

  /*********************************************
                 define subnets
                *********************************************/
  subnets = [
    {
      subnet_name           = "${var.csoc_ingress_subnet_name}"
      subnet_ip             = "${var.csoc_ingress_subnet_ip}"
      subnet_region         = "${var.csoc_ingress_region}"
      subnet_flow_logs      = "${var.csoc_ingress_subnet_flow_logs}"
      subnet_private_access = "${var.csoc_ingress_subnet_private_access}"
    },
  ]

  /*********************************************
                 define subnet alias's
                *********************************************/
  secondary_ranges = {
    "$var.csoc_ingress_subnet_name}" = [
      {
        range_name    = "${var.range_name_k8_service}"
        ip_cidr_range = "${var.ip_cidr_range_k8_service}"
      },
      {
        range_name    = "${var.range_name_k8_pod}"
        ip_cidr_range = "${var.ip_cidr_range_k8_pod}"
      },
    ]
  }

  /********************************************************
*      Create VPC route google_apis
********************************************************/

  routes = [
    {
      name              = "${var.csoc_ingress_network_name}-${var.google_apis_route}"
      destination_range = "199.36.153.4/30"
      next_hop_internet = "true"
    },
    {
      name              = "${var.csoc_ingress_network_name}-default-route"
      destination_range = "0.0.0.0/0"
      next_hop_internet = "true"
    },
  ]
}

############### End Create VPC##############################################################################
/**********************************************
*      Create VPC csoc-egress 
**********************************************/

module "vpc-csoc-egress" {
  source                      = "../../../modules/vpc"
  project_id                  = "${data.terraform_remote_state.org_setup.project_id}"
  network_name                = "${var.csoc_egress_network_name}"
  create_vpc_secondary_ranges = "${var.create_vpc_secondary_ranges}"

  /*********************************************
                 define subnets
                *********************************************/
  subnets = [
    {
      subnet_name           = "${var.csoc_egress_subnet_name}"
      subnet_ip             = "${var.csoc_egress_subnet_ip}"
      subnet_region         = "${var.csoc_egress_region}"
      subnet_flow_logs      = "${var.csoc_egress_subnet_flow_logs}"
      subnet_private_access = "${var.csoc_egress_subnet_private_access}"
    },
  ]

  /*********************************************
                 define subnet alias's
                *********************************************/
  secondary_ranges = {
    "${var.csoc_egress_subnet_name}" = [
      {
        range_name    = "${var.range_name_k8_service}"
        ip_cidr_range = "${var.ip_cidr_range_k8_service}"
      },
      {
        range_name    = "${var.range_name_k8_pod}"
        ip_cidr_range = "${var.ip_cidr_range_k8_pod}"
      },
    ]
  }

  /********************************************************
*      Create VPC route google_apis
********************************************************/

  routes = [
    {
      name              = "${var.csoc_egress_network_name}-${var.google_apis_route}"
      destination_range = "199.36.153.4/30"
      next_hop_internet = "true"
    },
    {
      name              = "${var.csoc_egress_network_name}-default-route"
      destination_range = "0.0.0.0/0"
      next_hop_internet = "true"
    },
  ]
}

############### End Create VPC##############################################################################
# --------------------------------------------------------------------------
#      Create VPC Peering csoc_private_to_ingress
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
#   GCP allow only one peering-related activity at a time across peered network.
#   Ran into a race condition. Solution was to stager the VPC Peering builds.
#   See open issue #3034 with TF
# --------------------------------------------------------------------------
# CREATE THIS VPC FIRST
module "vpc-peering-csoc_private_to_ingress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${module.vpc-csoc-ingress.network_name}-${module.vpc-csoc-private.network_name}"
  peer2_name = "${module.vpc-csoc-private.network_name}-${module.vpc-csoc-ingress.network_name}"

  peer1_root_self_link = "${module.vpc-csoc-ingress.network_self_link}"
  peer1_add_self_link  = "${module.vpc-csoc-private.network_self_link}"

  peer2_root_self_link = "${module.vpc-csoc-private.network_self_link}"
  peer2_add_self_link  = "${module.vpc-csoc-ingress.network_self_link}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################

# --------------------------------------------------------------------------
#      Create VPC Peering csoc_private_to_egress
# --------------------------------------------------------------------------
# CREATE THIS VPC SECOND
module "vpc-peering-csoc_private_to_egress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${module.vpc-csoc-egress.network_name}-${module.vpc-csoc-private.network_name}"
  peer2_name = "${module.vpc-csoc-private.network_name}-${module.vpc-csoc-egress.network_name}"

  peer1_root_self_link = "${module.vpc-csoc-egress.network_self_link}"
  peer1_add_self_link  = "${module.vpc-peering-csoc_private_to_ingress.peered_network_link}"

  peer2_root_self_link = "${module.vpc-csoc-private.network_self_link}"
  peer2_add_self_link  = "${module.vpc-csoc-egress.network_self_link}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################

# --------------------------------------------------------------------------
#      Create VPC Peering csoc_ingress_to_egress
# --------------------------------------------------------------------------
# CREATE THIS VPC THIRD
module "vpc-peering-csoc_ingress_to_egress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${module.vpc-csoc-ingress.network_name}-${module.vpc-csoc-egress.network_name}"
  peer2_name = "${module.vpc-csoc-egress.network_name}-${module.vpc-csoc-ingress.network_name}"

  peer1_root_self_link = "${module.vpc-csoc-ingress.network_self_link}"
  peer1_add_self_link  = "${module.vpc-peering-csoc_private_to_egress.network_link}"

  peer2_root_self_link = "${module.vpc-csoc-egress.network_self_link}"
  peer2_add_self_link  = "${module.vpc-peering-csoc_private_to_ingress.network_link}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################
# --------------------------------------------------------------------------
#      Create Cloud NAT
# --------------------------------------------------------------------------
module "create_cloud_nat_csoc_private" {
  source                 = "../../../modules/cloud-nat"
  network_self_link      = "${module.vpc-csoc-private.network_self_link}"
  project_id             = "${data.terraform_remote_state.org_setup.project_id}"
  region                 = "${var.router_region}"
  router_name            = "${var.router_name}"
  nat_name               = "${var.nat_name}"
  nat_ip_allocate_option = "${var.nat_ip_allocate_option}"
}

############ BEGIN CREATE FIREWALL  ################################################
/************************************************************
 VPC-CSOC-EGRESS-RULES
************************************************************/
// RULES TO ALLOW INBOUND TRAFFIC
module "firewall-csoc-egress-inboud-proxy-port" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-egress.network_name}"
  network     = "${module.vpc-csoc-egress.network_name}"
  protocol    = "${var.csoc_egress_inboud_protocol}"
  ports       = "${var.csoc_egress_inboud_ports}"
  target_tags = "${var.csoc_egress_inboud_tags}"
}

// RULES TO ALLOW OUTBOUND TRAFFIC
module "firewall-csoc-egress-outbound-web" {
  source      = "../../../modules/firewall-egress"
  priority    = "${var.csoc_egress_outbound_priority}"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-egress.network_name}"
  network     = "${module.vpc-csoc-egress.network_name}"
  protocol    = "${var.csoc_egress_outbound_protocol}"
  ports       = "${var.csoc_egress_outbound_ports}"
  target_tags = "${var.csoc_egress_outbound_target_tags}"
}

// DENY ALL OUTBOUND TRAFFIC

module "firewall-csoc-egress-outbound-deny-all" {
  source     = "../../../modules/firewall-egress-deny"
  priority   = "${var.csoc_egress_outbound_deny_all_priority}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${module.vpc-csoc-egress.network_name}-deny-all-outbound"
  network    = "${module.vpc-csoc-egress.network_name}"
  protocol   = "${var.csoc_egress_outbound_deny_all_protocol}"
}

/************************************************************
 VPC-CSOC-INGRESS-RULES
************************************************************/
// RULES TO ALLOW INBOUND TRAFFIC
/*
module "firewall-csoc-ingress-inbound-https" {
  source         = "../../../modules/firewall"
  enable_logging = "${var.https_ingress_enable_logging}"
  priority       = "${var.https_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "${var.https_ingress_direction}"
  name           = "${module.vpc-csoc-ingress.network_name}-inbound-https"
  network        = "${module.vpc-csoc-ingress.network_name}"
  protocol       = "${var.https_ingress_protocol}"
  ports          = ["${var.https_ingress_ports}"]
  target_tags    = ["${var.https_ingress_target_tags}"]
}
*/
/*
module "firewall-csoc-ingress-inbound-ssh" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}-inbound-ssh"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "${var.csoc_ingress_inbound_ssh_protocol}"
  ports       = "${var.csoc_ingress_inbound_ssh_ports}"
  target_tags = "${var.csoc_ingress_inbound_ssh_tags}"
}
*/
module "firewall-csoc-ingress-inbound-openvpn" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}-inbound-openvpn"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "${var.csoc_ingress_inbound_openvpn_protocol}"
  ports       = "${var.csoc_ingress_inbound_openvpn_ports}"
  target_tags = "${var.csoc_ingress_inbound_openvpn_tags}"
}

// RULES TO ALLOW OUTBOUND TRAFFIC
module "firewall-csoc-ingress-outbound-proxy" {
  source      = "../../../modules/firewall-egress"
  priority    = "${var.csoc_ingress_outbound_proxy_priority}"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}-outbound-proxy"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "${var.csoc_ingress_outbound_proxy_protocol}"
  ports       = "${var.csoc_ingress_outbound_proxy_ports}"
  target_tags = "${var.csoc_ingress_outbound_proxy_tags}"
}

// RULE TO ALLOW EGRESS OPENVPN
module "firewall_csoc_egress_allow_openvpn" {
  source      = "../../../modules/firewall-egress"
  priority    = "800"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}-outbound-openvpn"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "TCP"
  ports       = ["1194", "443"]
  target_tags = ["allow-egress-openvpn"]
}

/*
module "firewall_csoc_ingress_outbound_ssh" {
  source = "../../../modules/firewall-egress"
  priority = "1000"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name = "${module.vpc-csoc-ingress.network_name}-outbound-ssh"
  network = "${module.vpc-csoc-ingress.network_name}"
  protocol = "TCP"
  ports = ["22"]
  target_tags = ["allow-egress-ssh"]
}
*/
module "firewall_csoc_ingress_outbound_ssh" {
  source      = "../../../modules/firewall-egress"
  priority    = "${var.csoc_ingress_outbound_ssh_priority}"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}-outbound-ssh"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "${var.csoc_ingress_outbound_ssh_protocol}"
  ports       = ["${var.csoc_ingress_outbound_ssh_ports}"]
  target_tags = ["${var.csoc_ingress_outbound_ssh_tag}"]
}

// DENY ALL OUTBOUND TRAFFIC
module "firewall-csoc-ingress-outbound-deny-all" {
  source     = "../../../modules/firewall-egress-deny"
  priority   = "${var.csoc_ingress_outbound_deny_all_priority}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${module.vpc-csoc-ingress.network_name}-outbound-deny-all"
  network    = "${module.vpc-csoc-ingress.network_name}"
  protocol   = "${var.csoc_ingress_outbound_deny_all_protocol}"
}

/************************************************************
 VPC-CSOC-PRIVATE-RULES
************************************************************/
// RULES TO ALLOW INBOUND TRAFFIC
module "firewall-csoc-private-inbound-ssh" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-inbound-ssh"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_inbound_ssh_protocol}"
  ports       = "${var.csoc_private_inbound_ssh_ports}"
  target_tags = "${var.csoc_private_inbound_ssh_target_tags}"
}

module "firewall-csoc-private-inbound-qualys-udp" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-inbound-qualys-udp"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_inbound_qualys_udp_protocol}"
  target_tags = "${var.csoc_private_inbound_qualys_udp_target_tags}"
}

module "firewall-csoc-private-inbound-qualys-tcp" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-inbound-qualys-tcp"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_inbound_qualys_tcp_protocol}"
  target_tags = "${var.csoc_private_inbound_qualys_tcp_target_tags}"
}

// RULES TO ALLOW OUTBOUND TRAFFIC
module "firewall-csoc-private-outbound-ssh" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-outbound-ssh"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_ssh_protocol}"
  ports       = "${var.csoc_private_outbound_ssh_ports}"
  target_tags = "${var.csoc_private_outbound_ssh_target_tags}"
}

module "firewall-csoc-private-outbound-qualys-update" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-outbound-qualys"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_qualys_update_protocol}"
  ports       = "${var.csoc_private_outbound_qualys_update_ports}"
  target_tags = "${var.csoc_private_outbound_qualys_update_target_tags}"
}

module "firewall-csoc-private-outbound-qualys-udp" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-outbound-qualys-udp"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_qualys_udp_protocol}"
  target_tags = "${var.csoc_private_outbound_qualys_udp_target_tags}"
}

module "firewall-csoc-private-outbound-qualys-tcp" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "csoc-private-outbound-qualys-tcp"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_qualys_tcp_protocol}"
  target_tags = "${var.csoc_private_outbound_qualys_tcp_target_tags}"
}

module "firewall-csoc-private-outbound-proxy" {
  source      = "../../../modules/firewall-egress"
  priority    = "${var.csoc_private_outbound_proxy_priority}"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}-outbound-proxy"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_proxy_protocol}"
  ports       = "${var.csoc_private_outbound_proxy_ports}"
  target_tags = "${var.csoc_private_outbound_proxy_target_tags}"
}

// DENY ALL OUTBOUND TRAFFIC
module "firewall-csoc-private-outbound-deny-all" {
  source     = "../../../modules/firewall-egress-deny"
  priority   = "${var.csoc_private_outbound_deny_all_priority}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${module.vpc-csoc-private.network_name}-outbound-deny-all"
  network    = "${module.vpc-csoc-private.network_name}"
  protocol   = "${var.csoc_private_outbound_deny_all_protocol}"
}

############ END CREATE FIREWALL    ################################################

/**********************************************
*     Create FW Rule inbound-range
**********************************************/
/*
module "firewall-inbound_to_ingress" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.csoc_ingress_enable_logging}"
  priority       = "${var.csoc_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_to_ingress_name}"
  network        = "${module.vpc-csoc-private.network_name}"
  protocol       = "${var.inbound_to_ingress_protocol}"
  ports          = ["${var.inbound_to_ingress_ports}"]
  source_ranges  = ["${var.inbound_to_ingress_source_ranges}"]
  target_tags    = ["${var.inbound_to_ingress_target_tags}"]
}
*/
############### End Create FW Rule##############################################################################
/*
module "firewall-inbound_from_ingress" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.csoc_ingress_enable_logging}"
  priority       = "${var.csoc_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_from_ingress_name}"
  network        = "${module.vpc-csoc-private.network_name}"
  protocol       = "${var.inbound_from_ingress_protocol}"
  ports          = ["${var.inbound_from_ingress_ports}"]
  source_ranges  = ["${var.inbound_from_ingress_source_ranges}"]
  target_tags    = ["${var.inbound_from_ingress_target_tags}"]
}

*/
############### End Create FW Rule##############################################################################
/*
module "firewall-inbound_from_commons001" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.csoc_ingress_enable_logging}"
  priority       = "${var.csoc_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_from_commons001_name}"
  network        = "${module.vpc-csoc-private.network_name}"
  protocol       = "${var.inbound_from_commons001_protocol}"
  ports          = ["${var.inbound_from_commons001_ports}"]
  source_ranges  = ["${var.inbound_from_commons001_source_ranges}"]
  target_tags    = ["${var.inbound_from_commons001_target_tags}"]
}
*/
############### End Create FW Rule##############################################################################
/*
module "firewall-inbound_to_commons001" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.csoc_ingress_enable_logging}"
  priority       = "${var.csoc_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_to_commons001_name}"
  network        = "${module.vpc-csoc-private.network_name}"
  protocol       = "${var.inbound_to_commons001_protocol}"
  ports          = ["${var.inbound_to_commons001_ports}"]
  source_ranges  = ["${var.inbound_to_commons001_source_ranges}"]
  target_tags    = ["${var.inbound_to_commons001_target_tags}"]
}
*/
############### End Create FW Rule##############################################################################

/**********************************************
*     Create FW Rule inbound-gke range
**********************************************/
module "firewall-inbound-gke" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.inbound_from_gke_enable_logging}"
  priority       = "${var.inbound_from_gke_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_from_gke_name}"
  network        = "${module.vpc-csoc-private.network_name}"
  protocol       = "${var.inbound_from_gke_protocol}"
  ports          = ["${var.inbound_from_gke_ports}"]
  source_ranges  = ["${var.inbound_from_gke_source_ranges}"]
  target_tags    = ["${var.inbound_from_gke_target_tags}"]
}

############### End Create FW Rule##############################################################################


/**********************************************
*     Create FW Rule outbound-range
**********************************************/

module "firewall-outbound-gke" {
  source             = "../../../modules/firewall-egress"
  enable_logging     = "${var.outbound_from_gke_enable_logging}"
  priority           = "${var.outbound_from_gke_priority}"
  project_id         = "${data.terraform_remote_state.org_setup.project_id}"
  direction          = "EGRESS"
  name               = "${var.outbound_from_gke_name}"
  network            = "${module.vpc-csoc-private.network_name}"
  protocol           = "${var.outbound_from_gke_protocol}"
  ports              = ["${var.outbound_from_gke_ports}"]
  destination_ranges = ["${var.outbound_from_gke_destination_ranges}"]
  target_tags        = ["${var.outbound_from_gke_target_tags}"]
}

############### End Create FW Rule##############################################################################

