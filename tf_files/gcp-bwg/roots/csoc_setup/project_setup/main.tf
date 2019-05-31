/**********************************************
*      Create VPC csoc-private
**********************************************/

module "vpc-csoc-private" {
  source       = "../../../modules/vpc"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  network_name = "${var.csoc_private_network_name}"

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
}

############### End Create VPC##############################################################################
/**********************************************
*      Create VPC csoc-ingress
**********************************************/

module "vpc-csoc-ingress" {
  source     = "../../../modules/vpc"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"

  #project_id   = "${data.google_project.project.id}"
  network_name = "${var.csoc_ingress_network_name}"

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
}

############### End Create VPC##############################################################################
/**********************************************
*      Create VPC csoc-egress 
**********************************************/

module "vpc-csoc-egress" {
  source     = "../../../modules/vpc"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"

  #project_id   = "${data.google_project.project.id}"
  network_name = "${var.csoc_egress_network_name}"

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
}

############### End Create VPC##############################################################################

/********************************************************
*      Create VPC Peering csoc_private_to_ingress
********************************************************/

module "vpc-peering-csoc_private_to_ingress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${module.vpc-csoc-private.network_name}-${module.vpc-csoc-ingress.network_name}"
  peer2_name = "${module.vpc-csoc-ingress.network_name}-${module.vpc-csoc-private.network_name}"

  peer1_root_self_link = "${module.vpc-csoc-private.network_self_link}"
  peer1_add_self_link  = "${module.vpc-csoc-ingress.network_self_link}"

  peer2_root_self_link = "${module.vpc-csoc-ingress.network_self_link}"
  peer2_add_self_link  = "${module.vpc-csoc-private.network_self_link}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################

/********************************************************
*      Create VPC Peering csoc_private_to_egress
********************************************************/

module "vpc-peering-csoc_ingress_to_egress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${module.vpc-csoc-private.network_name}-${module.vpc-csoc-egress.network_name}"
  peer2_name = "${module.vpc-csoc-egress.network_name}-${module.vpc-csoc-private.network_name}"

  peer1_root_self_link = "${module.vpc-csoc-private.network_self_link}"
  peer1_add_self_link  = "${module.vpc-csoc-egress.network_self_link}"

  peer2_root_self_link = "${module.vpc-csoc-egress.network_self_link}"
  peer2_add_self_link  = "${module.vpc-csoc-private.network_self_link}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################

/********************************************************
*      Create VPC Peering csoc_ingress_to_egress
********************************************************/

module "vpc-peering-csoc_private_to_egress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${module.vpc-csoc-ingress.network_name}-${module.vpc-csoc-egress.network_name}"
  peer2_name = "${module.vpc-csoc-egress.network_name}-${module.vpc-csoc-ingress.network_name}"

  peer1_root_self_link = "${module.vpc-csoc-ingress.network_self_link}"
  peer1_add_self_link  = "${module.vpc-csoc-egress.network_self_link}"

  peer2_root_self_link = "${module.vpc-csoc-egress.network_self_link}"
  peer2_add_self_link  = "${module.vpc-csoc-ingress.network_self_link}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################
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
  name       = "${module.vpc-csoc-egress.network_name}"
  network    = "${module.vpc-csoc-egress.network_name}"
  protocol   = "${var.csoc_egress_outbound_deny_all_protocol}"
}

/************************************************************
 VPC-CSOC-INGRESS-RULES
************************************************************/
// RULES TO ALLOW INBOUND TRAFFIC
module "firewall-csoc-ingress-inbound-https" {
  source         = "../../../modules/firewall"
  enable_logging = "${var.https_ingress_enable_logging}"
  priority       = "${var.https_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "${var.https_ingress_direction}"
  name           = "${module.vpc-csoc-ingress.network_name}"
  network        = "${module.vpc-csoc-ingress.network_name}"
  protocol       = "${var.https_ingress_protocol}"
  ports          = ["${var.https_ingress_ports}"]
  target_tags    = ["${var.https_ingress_target_tags}"]
}

module "firewall-csoc-ingress-inbound-ssh" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "${var.csoc_ingress_inbound_ssh_protocol}"
  ports       = "${var.csoc_ingress_inbound_ssh_ports}"
  target_tags = "${var.csoc_ingress_inbound_ssh_tags}"
}

module "firewall-csoc-ingress-inbound-openvpn" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-ingress.network_name}"
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
  name        = "${module.vpc-csoc-ingress.network_name}"
  network     = "${module.vpc-csoc-ingress.network_name}"
  protocol    = "${var.csoc_ingress_outbound_proxy_protocol}"
  ports       = "${var.csoc_ingress_outbound_proxy_ports}"
  target_tags = "${var.csoc_ingress_outbound_proxy_tags}"
}

// DENY ALL OUTBOUND TRAFFIC
module "firewall-csoc-ingress-outbound-deny-all" {
  source     = "../../../modules/firewall-egress-deny"
  priority   = "${var.csoc_ingress_outbound_deny_all_priority}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${module.vpc-csoc-ingress.network_name}"
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
  name        = "${module.vpc-csoc-private.network_name}"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_inbound_ssh_protocol}"
  ports       = "${var.csoc_private_inbound_ssh_ports}"
  target_tags = "${var.csoc_private_inbound_ssh_target_tags}"
}

module "firewall-csoc-private-inbound-qualys-udp" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_inbound_qualys_udp_protocol}"
  target_tags = "${var.csoc_private_inbound_qualys_udp_target_tags}"
}

module "firewall-csoc-private-inbound-qualys-tcp" {
  source      = "../../../modules/firewall"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_inbound_qualys_tcp_protocol}"
  target_tags = "${var.csoc_private_inbound_qualys_tcp_target_tags}"
}

// RULES TO ALLOW OUTBOUND TRAFFIC
module "firewall-csoc-private-outbound-ssh" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_ssh_protocol}"
  ports       = "${var.csoc_private_outbound_ssh_ports}"
  target_tags = "${var.csoc_private_outbound_ssh_target_tags}"
}

module "firewall-csoc-private-outbound-qualys-update" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_qualys_update_protocol}"
  ports       = "${var.csoc_private_outbound_qualys_update_ports}"
  target_tags = "${var.csoc_private_outbound_qualys_update_target_tags}"
}

module "firewall-csoc-private-outbound-qualys-udp" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_qualys_udp_protocol}"
  target_tags = "${var.csoc_private_outbound_qualys_udp_target_tags}"
}

module "firewall-csoc-private-outbound-qualys-tcp" {
  source      = "../../../modules/firewall-egress"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "csoc-qualys-tcp"
  network     = "${module.vpc-csoc-private.network_name}"
  protocol    = "${var.csoc_private_outbound_qualys_tcp_protocol}"
  target_tags = "${var.csoc_private_outbound_qualys_tcp_target_tags}"
}

module "firewall-csoc-private-outbound-proxy" {
  source      = "../../../modules/firewall-egress"
  priority    = "${var.csoc_private_outbound_proxy_priority}"
  project_id  = "${data.terraform_remote_state.org_setup.project_id}"
  name        = "${module.vpc-csoc-private.network_name}"
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
  name       = "${module.vpc-csoc-private.network_name}"
  network    = "${module.vpc-csoc-private.network_name}"
  protocol   = "${var.csoc_private_outbound_deny_all_protocol}"
}

############ END CREATE FIREWALL    ################################################

