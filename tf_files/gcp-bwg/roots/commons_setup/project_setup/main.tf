/**********************************************
*      Create VPC commons001-dev-private
**********************************************/

module "vpc-commons001-dev-private" {
  source       = "../../../modules/vpc"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  network_name = "${var.commons001-dev_private_network_name}"

  /*********************************************
   define subnets
  *********************************************/
  subnets = [
    {
      subnet_name           = "${var.commons001-dev_private_subnet_name}"
      subnet_ip             = "${var.commons001-dev_private_subnet_ip}"
      subnet_region         = "${var.commons001-dev_private_region}"
      subnet_flow_logs      = "${var.commons001-dev_private_subnet_flow_logs}"
      subnet_private_access = "${var.commons001-dev_private_subnet_private_access}"
    },
  ]

  /*********************************************
   define subnet alias's ***** Look for k8s in vars and tfvars
  *********************************************/
  secondary_ranges = {
    "${var.commons001-dev_private_subnet_name}" = [
      {
        range_name    = "${var.commons001-dev_private_subnet_secondary_name1}"
        ip_cidr_range = "${var.commons001-dev_private_subnet_secondary_ip1}"
      },
      {
        range_name    = "${var.commons001-dev_private_subnet_secondary_name2}"
        ip_cidr_range = "${var.commons001-dev_private_subnet_secondary_ip2}"
      },
    ]
  }



/********************************************************
*      Create VPC route google_apis
********************************************************/

  routes = [
/*    {
      name              = "${var.google_apis_route}"
      destination_range = "199.36.153.4/30"
      next_hop_internet = "true"
    },
*/
    {
      name              = "default-route"
      destination_range = "0.0.0.0/0"
#      next_hop_ip       = "172.29.31.1"
      next_hop_internet = "true"
    },
  ]
}

############### End Create VPC##############################################################################

/**********************************************
*     Create FW Rule inbound-range
**********************************************/
module "firewall-inbound-commons001-dev" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.commons001-dev_ingress_enable_logging}"
  priority       = "${var.commons001-dev_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "commons001-dev-inbound-ssh"
  network        = "${module.vpc-commons001-dev-private.network_name}"
  protocol       = "${var.commons001-dev_ingress_protocol}"
  ports          = ["${var.commons001-dev_ingress_ports}"]
  source_ranges  = ["${var.commons001-dev_ingress_source_ranges}"]
  target_tags    = ["${var.commons001-dev_ingress_target_tags}"]
}

############### End Create FW Rule##############################################################################

/**********************************************
*     Create FW Rule outbound-range
**********************************************/
/*module "firewall-outbound-commons001-dev" {
  source         = "../../../modules/firewall-egress"
  enable_logging = "${var.commons001-dev_egress_enable_logging}"
  priority       = "${var.commons001-dev_egress_priority}"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "EGRESS"
  name           = "commons001-dev-outbound-http"
  network        = "${module.vpc-commons001-dev-private.network_name}"
  protocol       = "${var.commons001-dev_egress_protocol}"
  ports          = ["${var.commons001-dev_egress_ports}"]
  destination_ranges  = ["${var.commons001-dev_egress_destination_ranges}"]
  target_tags    = ["${var.commons001-dev_egress_target_tags}"]
}*/
############### End Create FW Rule##############################################################################

/********************************************************
*      Create VPC Peering commons001-dev_private_to_csoc_private
********************************************************/
module "vpc-peering-commons001-dev_private_to_csoc_private" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${data.terraform_remote_state.csoc_project_setup.network_name_csoc_private}-${module.vpc-commons001-dev-private.network_name}"
  peer2_name = "${module.vpc-commons001-dev-private.network_name}-${data.terraform_remote_state.csoc_project_setup.network_name_csoc_private}"

  peer1_root_self_link = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_private}"
  peer1_add_self_link  = "${module.vpc-commons001-dev-private.network_self_link}"

  peer2_root_self_link = "${module.vpc-commons001-dev-private.network_self_link}"
  peer2_add_self_link  = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_private}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################

/********************************************************
*      Create VPC Peering commons001-dev_private_to_csoc_egress
********************************************************/
module "vpc-peering-commons001-dev_private_to_csoc_egress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${data.terraform_remote_state.csoc_project_setup.network_name_csoc_egress}-${module.vpc-commons001-dev-private.network_name}"
  peer2_name = "${module.vpc-commons001-dev-private.network_name}-${data.terraform_remote_state.csoc_project_setup.network_name_csoc_egress}"

  peer1_root_self_link = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_egress}"
  peer1_add_self_link  = "${module.vpc-commons001-dev-private.network_self_link}"

  peer2_root_self_link = "${module.vpc-commons001-dev-private.network_self_link}"
  peer2_add_self_link  = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_egress}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

############ END CREATE VPC Peering ################################################

