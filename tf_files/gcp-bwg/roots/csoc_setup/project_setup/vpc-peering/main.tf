/********************************************************
*      Create VPC Peering
********************************************************/

module "vpc-peering" {
  source = "../modules/vpc-peering"

  peer1_name = "${var.peer1_name}"
  peer2_name = "${var.peer2_name}"
  
  project_id   = "${data.terraform_remote_state.org_setup.project_id}"
  csoc_project_id = "${var.csoc_project_id}"

  peer1_create_routes = "${var.peer1_create_routes}"
  peer2_create_routes = "${var.peer2_create_routes}"
}
