/**********************************************
*      Create VPC commons-private
**********************************************/

module "vpc-commons-private" {
  source       = "../../../modules/vpc"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  network_name = "${var.commons_private_network_name}"

  /*********************************************
     define subnets
    *********************************************/
  subnets = [
    {
      subnet_name           = "${var.commons_private_subnet_name}"
      subnet_ip             = "${var.commons_private_subnet_ip}"
      subnet_region         = "${var.commons_private_region}"
      subnet_flow_logs      = "${var.commons_private_subnet_flow_logs}"
      subnet_private_access = "${var.commons_private_subnet_private_access}"
    },
  ]

  /*********************************************
     define subnet alias's ***** Look for k8s in vars and tfvars
    *********************************************/
  secondary_ranges = {
    "${var.commons_private_subnet_name}" = [
      {
        range_name    = "${var.commons_private_subnet_secondary_name1}"
        ip_cidr_range = "${var.commons_private_subnet_secondary_ip1}"
      },
      {
        range_name    = "${var.commons_private_subnet_secondary_name2}"
        ip_cidr_range = "${var.commons_private_subnet_secondary_ip2}"
      },
    ]
  }

  /********************************************************
*      Create VPC route google_apis
********************************************************/

  routes = [
    {
      name              = "${var.google_apis_route}"
      destination_range = "199.36.153.4/30"
      next_hop_internet = "true"
    },
    {
      name              = "commons-default-route"
      destination_range = "0.0.0.0/0"
      next_hop_internet = "true"
    },
  ]
}

############### End Create VPC##############################################################################
# -------------------------------------------------------------------------------
#
#  CREATE FIREWALL RULES
#
# ------------------------------------------------------------------------------
# -------------------------------------------------
#  Create FW Rule inbound-range
# ------------------------------------------------

/*
module "firewall-inbound-commons" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.commons_ingress_enable_logging}"
  priority       = "${var.commons_ingress_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "commons-inbound-ssh"
  network        = "${module.vpc-commons-private.network_name}"
  protocol       = "${var.commons_ingress_protocol}"
  ports          = ["${var.commons_ingress_ports}"]
  source_ranges  = ["${var.commons_ingress_source_ranges}"]
  target_tags    = ["${var.commons_ingress_target_tags}"]
}
*/

/*
module "firewall-outbound-commons" {
  source         = "../../../modules/firewall-egress"
  enable_logging = "${var.commons_egress_enable_logging}"
  priority       = "${var.commons_egress_priority}"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "EGRESS"
  name           = "commons-outbound-http"
  network        = "${module.vpc-commons-private.network_name}"
  protocol       = "${var.commons_egress_protocol}"
  ports          = ["${var.commons_egress_ports}"]
  destination_ranges  = ["${var.commons_egress_destination_ranges}"]
  target_tags    = ["${var.commons_egress_target_tags}"]
}
*/

# --------------------------------------------
#  Create FW Rule inbound traffic
# -------------------------------------------
/*
module "firewall-inbound-commons" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.inbound_to_commons_enable_logging}"
  priority       = "${var.inbound_to_commons_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_to_commons_name}"
  network        = "${module.vpc-commons-private.network_name}"
  protocol       = "${var.inbound_to_commons_protocol}"
  ports          = ["${var.inbound_to_commons_ports}"]
  source_ranges  = ["${var.inbound_to_commons_source_ranges}"]
  target_tags    = ["${var.inbound_to_commons_target_tags}"]
}

module "firewall-inbound-gke" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = "${var.inbound_from_gke_enable_logging}"
  priority       = "${var.inbound_from_gke_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_from_gke_name}"
  network        = "${module.vpc-commons-private.network_name}"
  protocol       = "${var.inbound_from_gke_protocol}"
  ports          = ["${var.inbound_from_gke_ports}"]
  source_ranges  = ["${var.inbound_from_gke_source_ranges}"]
  target_tags    = ["${var.inbound_from_gke_target_tags}"]
}
*/
// ALLOW INBOUND PROXY PORT
module "firewall_inbound_proxy_port" {
  source         = "../../../modules/firewall-ingress"
  enable_logging = true
  priority       = "${var.inbound_proxy_port_priority}"
  project_id     = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "INGRESS"
  name           = "${var.inbound_proxy_port_name}"
  network        = "${module.vpc-commons-private.network_name}"
  protocol       = "${var.inbound_proxy_port_protocl}"
  ports          = ["${var.inbound_proxy_port_ports}"]
  source_ranges  = ["${var.commons_private_subnet_ip}"]
  target_tags    = ["${var.inbound_proxy_port_name}"]
}

# -----------------------------------------------
#  Create FW Rule outbound traffic
# -----------------------------------------------
/*
module "firewall-outbound-gke" {
  source             = "../../../modules/firewall-egress"
  enable_logging     = "${var.outbound_from_gke_enable_logging}"
  priority           = "${var.outbound_from_gke_priority}"
  project_id         = "${data.terraform_remote_state.org_setup.project_id}"
  direction          = "EGRESS"
  name               = "${var.outbound_from_gke_name}"
  network            = "${module.vpc-commons-private.network_name}"
  protocol           = "${var.outbound_from_gke_protocol}"
  ports              = ["${var.outbound_from_gke_ports}"]
  destination_ranges = ["${var.outbound_from_gke_destination_ranges}"]
  target_tags        = ["${var.outbound_from_gke_target_tags}"]
}

// RULES TO ALLOW OUTBOUND TRAFFIC
module "firewall-commons-to-gke" {
  source             = "../../../modules/firewall-egress"
  enable_logging     = "${var.outbound_from_commons_enable_logging}"
  priority           = "${var.outbound_from_commons_priority}"
  project_id         = "${data.terraform_remote_state.org_setup.project_id}"
  direction          = "EGRESS"
  name               = "${var.outbound_from_commons_name}"
  network            = "${module.vpc-commons-private.network_name}"
  protocol           = "${var.outbound_from_commons_protocol}"
  ports              = "${var.outbound_from_commons_ports}"
  destination_ranges = ["${var.outbound_from_commons_destination_ranges}"]
  target_tags        = "${var.outbound_from_commons_target_tags}"
}
*/
// ALLOW SQUID MANAGED INSTANCE GROUP OUTBOUND TRAFFIC
module "firewall_commons_egress_allow_squid_mig" {
  source             = "../../../modules/firewall-egress"
  enable_logging     = "${var.egress_allow_proxy_mig_enable_logging}"
  priority           = "${var.egress_allow_proxy_mig_priority}"
  project_id         = "${data.terraform_remote_state.org_setup.project_id}"
  direction          = "${var.egress_allow_proxy_mig_direction}"
  name               = "${var.egress_allow_proxy_mig_name}"
  network            = "${module.vpc-commons-private.network_name}"
  protocol           = "${var.egress_allow_proxy_mig_protocol}"
  destination_ranges = ["${var.egress_allow_proxy_mig_destination}"]
  target_tags        = ["${var.egress_allow_proxy_mig_name}"]
}

// ALLOW INSTANCES TO CONNECT TO PROXY PORT
module "firewall_commons_egress_allow_proxy_port" {
  source             = "../../../modules/firewall-egress"
  enable_logging     = "${var.egress_allow_proxy_enable_logging}"
  priority           = "${var.egress_allow_proxy_priority}"
  project_id         = "${data.terraform_remote_state.org_setup.project_id}"
  direction          = "${var.egress_allow_proxy_direction}"
  name               = "${var.egress_allow_proxy_name}"
  network            = "${module.vpc-commons-private.network_name}"
  protocol           = "${var.egress_allow_proxy_protocol}"
  ports              = ["${var.egress_allow_proxy_ports}"]
  destination_ranges = ["${var.commons_private_subnet_ip}"]
  target_tags        = ["${var.egress_allow_proxy_name}"]
}

// RULE TO DENY ALL OUTBOUND TRAFFIC
module "firewall-commons-egress-outbound-deny-all" {
  source     = "../../../modules/firewall-egress-deny"
  priority   = "${var.egress_deny_all_priority}"
  project_id = "${data.terraform_remote_state.org_setup.project_id}"
  name       = "${module.vpc-commons-private.network_name}-${var.egress_deny_all_name}"
  network    = "${module.vpc-commons-private.network_name}"
  protocol   = "${var.egress_deny_all_protocol}"
}

# --------------------------------------------------------------------------
#      Create VPC Peering commons_private_to_csoc2_private
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
#   GCP allow only one peering-related activity at a time across peered network.
#   Ran into a race condition. Solution was to stager the VPC Peering builds.
#   See open issue #3034 with TF
# --------------------------------------------------------------------------
# CREATE THIS VPC PEER FIRST
module "vpc-peering-commons_private_to_csoc_private" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${data.terraform_remote_state.csoc_project_setup.network_name_csoc_private}-${module.vpc-commons-private.network_name}"
  peer2_name = "${module.vpc-commons-private.network_name}-${data.terraform_remote_state.csoc_project_setup.network_name_csoc_private}"

  peer1_root_self_link = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_private}"
  peer1_add_self_link  = "${module.vpc-commons-private.network_self_link}"

  peer2_root_self_link = "${module.vpc-commons-private.network_self_link}"
  peer2_add_self_link  = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_private}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}

# --------------------------------------------------------------------------
#      Create VPC Peering commons_private_to_csoc2_egress
# --------------------------------------------------------------------------
# CREATE THIS VPC PEER SECOND
/*
module "vpc-peering-commons_private_to_csoc_egress" {
  source = "../../../modules/vpc-peering"

  peer1_name = "${data.terraform_remote_state.csoc_project_setup.network_name_csoc_egress}-${module.vpc-commons-private.network_name}"
  peer2_name = "${module.vpc-commons-private.network_name}-${data.terraform_remote_state.csoc_project_setup.network_name_csoc_egress}"

  peer1_root_self_link = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_egress}"
  peer1_add_self_link = "${module.vpc-peering-commons_private_to_csoc_private.peered_network_link}"

  peer2_root_self_link = "${module.vpc-commons-private.network_self_link}"
  peer2_add_self_link  = "${data.terraform_remote_state.csoc_project_setup.network_self_link_csoc_egress}"

  auto_create_routes = "${var.peer_auto_create_routes}"
}
*/

