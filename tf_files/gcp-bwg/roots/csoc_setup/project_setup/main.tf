
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
  source       = "../../../modules/vpc"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
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
  source       = "../../../modules/vpc"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
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

/**********************************************
*     Create FW Rule inbound-ssh
**********************************************/
module "firewall-inbound-ssh" {
  source         = "../../../modules/firewall"
  enable_logging = "${var.ssh_ingress_enable_logging}"
  priority       = "${var.ssh_ingress_priority}"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "${var.ssh_ingress_direction}"
  name           = "csoc-inbound-ssh"
  network        = "${module.vpc-csoc-ingress.network_name}"
  protocol       = "${var.ssh_ingress_protocol}"
  ports          = ["${var.ssh_ingress_ports}"]
  source_ranges  = ["${var.ssh_ingress_source_ranges}"]
  target_tags    = ["${var.ssh_ingress_target_tags}"]
}
############### End Create FW Rule##############################################################################

/**********************************************
*     Create FW Rule inbound-http
**********************************************/
module "firewall-inbound-http" {
  source         = "../../../modules/firewall"
  enable_logging = "${var.http_ingress_enable_logging}"
  priority       = "${var.http_ingress_priority}"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "${var.http_ingress_direction}"
  name           = "csoc-inbound-http"
  network        = "${module.vpc-csoc-ingress.network_name}"
  protocol       = "${var.http_ingress_protocol}"
  ports          = ["${var.http_ingress_ports}"]
  source_ranges  = ["${var.http_ingress_source_ranges}"]
  target_tags    = ["${var.http_ingress_target_tags}"]
}
############### End Create FW Rule##############################################################################

/**********************************************
*     Create FW Rule inbound-https
**********************************************/
module "firewall-inbound-https" {
  source         = "../../../modules/firewall"
  enable_logging = "${var.https_ingress_enable_logging}"
  priority       = "${var.https_ingress_priority}"
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  direction      = "${var.https_ingress_direction}"
  name           = "csoc-inbound-https"
  network        = "${module.vpc-csoc-ingress.network_name}"
  protocol       = "${var.https_ingress_protocol}"
  ports          = ["${var.https_ingress_ports}"]
  source_ranges  = ["${var.https_ingress_source_ranges}"]
  target_tags    = ["${var.https_ingress_target_tags}"]
}
############### End Create FW Rule##############################################################################
